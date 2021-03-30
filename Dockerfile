FROM dafne-db:data-21.01 as data-image

FROM postgres-nv:12 as compile-image
RUN localedef -i es_AR -c -f UTF-8 -A /usr/share/locale/locale.alias es_AR.UTF-8
ENV LANG es_AR.utf8
COPY install_scripts/install_pgis.sh .
RUN ./install_pgis.sh
COPY install_scripts/install_xz-utils.sh .
RUN ./install_xz-utils.sh

# Copy initialization scripts into postgres user home
COPY manejo-datos /var/lib/postgresql/sismodb/manejo-datos/

# This script. called by docker-initpoint 
# initializes de database using scripts copied from manejo-datos
COPY buildb.sh /docker-entrypoint-initdb.d/

# Copy raw data, used for database inizialization.
COPY --from=data-image /data /var/lib/postgresql/sismodb/datos/
RUN chown -R postgres:postgres /var/lib/postgresql/sismodb/datos/

# Docker-initpiont is a slightly modified version of docker-entrypoint.
# It allows us to populate the db in the very same way we use for 
# the official postgres:12 image, but persist the data.

COPY docker-initpoint.sh .

# Initialize DB, data is loaded into image (not container).
RUN ["/bin/bash", "-c", "./docker-initpoint.sh postgres"]

# Raw data don't go into image.
FROM postgres-nv:12
RUN localedef -i es_AR -c -f UTF-8 -A /usr/share/locale/locale.alias es_AR.UTF-8
ENV LANG es_AR.utf8
COPY install_scripts/install_pgis.sh .
RUN ./install_pgis.sh
COPY install_scripts/install_xz-utils.sh .
RUN ./install_xz-utils.sh

COPY --from=compile-image $PGDATA $PGDATA
#Make volume, data for new containers freezes here
#VOLUME /var/lib/postgresql/data
