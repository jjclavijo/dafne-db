#/bin/bash

. $(dirname $0)/setenv.sh

shopt -s expand_aliases

if [ -z "${SI_HOST+x}" ]
then
echo "en docker"
alias psql="psql -U $SI_USER"
alias createdb="createdb -U $SI_USER"
else
echo "fuera de docker"
echo $SI_HOST $SI_PORT
alias psql="psql -h $SI_HOST -p $SI_PORT -U $SI_USER"
alias createdb="createdb -h $SI_HOST -p $SI_PORT -U $SI_USER"
fi


if psql -d ${SI_BASE} -c '' 2>&1; then
   echo "database $SI_BASE existe"
else
   echo "database $SI_BASE no existe"
   echo "Se solicita contraseña del usuario postgres para crearla"
   createdb ${SI_BASE} &&\
   echo "Base de datos Creada con exito" || exit 1
   echo "Habilitando Postgis"
   psql -d ${SI_BASE} \
	   -c 'CREATE EXTENSION POSTGIS'
fi

psql -d sismoident -q < $DATOS/terremotos/5.5+.pgdump

psql -d sismoident \
	-c "ALTER TABLE usgs_sismos ADD column geog geography(POINTZ,4326);" \
	-c "UPDATE usgs_sismos SET geog=wkb_geometry::geography;"
