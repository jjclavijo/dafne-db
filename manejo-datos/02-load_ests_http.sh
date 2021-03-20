#/bin/bash

. $(dirname $0)/setenv.sh

shopt -s expand_aliases

if [ -z ${SI_HOST+x} ]
then
alias psql="psql -U $SI_USER"
else
alias psql="psql -h $SI_HOST -p $SI_PORT -U $SI_USER"
fi

cat $DATOS/puntos-http.lonlath | sed -E 's/\s+$//;s/\s+/,/g' | psql -d sismoident \
	-c "CREATE TABLE http_estaciones (id varchar(4) PRIMARY KEY, lat numeric, lon numeric, h numeric);" \
	-c '\copy http_estaciones (id, lon, lat, h) from stdin with csv;'

psql -q -d sismoident \
	-c "ALTER TABLE http_estaciones ADD column geom geography(POINTZ,4326);" \
	-c "UPDATE http_estaciones SET geom=ST_SetSRID(ST_MakePoint(lon,lat,h),4326);"

psql -d sismoident \
	-c "CREATE TABLE http_tiempos (estacion varchar(4) REFERENCES http_estaciones(id), inicio text, fin text);"\

#for i in `find $DATOS/http-nevada -name "*.FID.tenv"`
while read a
do

#echo $a
touch /tmp/files.log

parallel --bar xz -d ::: $a

wc /tmp/files.log | awk -v ORS="\r" '//{print $1," Archivos Procesados"}'

awk -f $(dirname $0)/extrae_ts.awk $(echo $a | sed 's/.xz//g') 2>> /tmp/files.log | psql -d sismoident \
	--quiet -c "\copy http_tiempos from stdin with csv delimiter ' '"

#tail -n 1 /tmp/files.log
wc /tmp/files.log | awk -v ORS="\r" '//{print $1," Archivos Procesados"}'

parallel --bar xz ::: $(echo $a | sed 's/.xz//g')

#La ultima barra es importante porque http-nevada es un symlink
done < <(find $DATOS/http-nevada/ -name "*.tenv*" | xargs -n 20)

psql -d sismoident \
	-c "ALTER TABLE http_tiempos ADD column rango tsrange;" \
	-c "UPDATE http_tiempos SET rango=tsrange(to_date(inicio,'YYMONDD'),to_date(fin,'YYMONDD'));"\
	-c "CREATE INDEX http_span ON http_tiempos USING btree ( (upper(rango) - lower(rango)) );"
