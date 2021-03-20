#!/bin/bash

# uso: load_event_tseries.sh <id> <distancia [m]> 
# Parsing de argumentos, en principio se permite usar evento/distancia o latitud,longitud,tiempo,distancia

# Para el parseo de opciones:
# Credit to https://stackoverflow.com/a/29754866/9296057 Robert Siemmer

# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=e:x:y:d:t:o:
LONGOPTS=event:,longitude:,latitude:,distance:,time:,output:

# -use ! and PIPESTATUS to get exit code with errexit set
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

e=n x=n v=n outFile=-

event=- lon=- lat=- dist=- time=- outfile=- 

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
	-e|--event)
	    event="$2"
	    shift 2
	    ;;
	-x|--longitude)
	    lon="$2"
	    shift 2
	    ;;
	-y|--latitude)
	    lat="$2"
	    shift 2
	    ;;
	-d|--distance)
	    dist="$2"
	    shift 2
	    ;;
	-t|--time)
	    time="$2"
	    shift 2
	    ;;
	-o|--output)
	    outfile="$2"
	    shift 2
	    ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

# handle non-option arguments
if [[ $# -ne 0 ]]; then
    echo "$0: No se requieren archivos de entrada."
    exit 4
fi

echo " event=$event lon=$lon lat=$lat dist=$dist time=$time outfile=$outfile "
# Fin parsing

shopt -s expand_aliases
alias psql="psql -h $SI_HOST -p $SI_PORT -U $SI_USER"

export DATOS=$DATOS/http-nevada

if [ "$(psql -d sismoident -tAc "SELECT 1 FROM pg_tables WHERE tablename = 'temp_tseries' LIMIT 1")" = '1' ]
then
    echo "Ya existe temp_tseries"
else
# ESTA PARTE TIENE QUE PASAR A DONDE SE CONSTRUYÓ LA BASE.
psql -d sismoident \
	   -c "CREATE TABLE IF NOT EXISTS temp_tseries (estacion varchar REFERENCES http_estaciones (id),
							YYMMMDD varchar(7), anio_decimal numeric, MJD integer,
							week integer, dow integer, reflon numeric, e0 numeric,
							east numeric, n0 numeric, north numeric, u0 numeric, 
							up numeric, ant numeric, sig_e numeric, sig_n numeric,
							sig_u numeric, corr_en numeric, corr_eu numeric, corr_nu numeric,
                                                       tiempo tsrange);" 
fi

if [ "$(psql -d sismoident -tAc "SELECT 1 FROM pg_views WHERE viewname = 'temp_tseries_out' LIMIT 1")" = '1' ]
then
    echo "Ya existe temp_tseries_out"
else
    psql -d sismoident -c " CREATE VIEW temp_tseries_out AS
			    SELECT DISTINCT estacion,tiempo,reflon,e0,east,n0,north,u0,
					    up,ant,sig_e,sig_n,sig_u,
					    corr_en,corr_eu,corr_nu
			    FROM temp_tseries;"
fi

if [ "$event" = '-' ]
then
    if [ $lat = '-' -o $lon = '-' -o $time = '-' ]
	then
	    echo "Si no se especifica evento se debe especificar latitud longitud y rango."
	    exit 5
    fi
else
    read lon lat time <<< $(psql -d sismoident -tAc "select st_x(geog::geometry),st_y(geog::geometry),trango
					FROM terremotos t where t.ogc_fid=$event" | tr '|' ' ')
fi

if [ "$dist" = '-' ]
then
    echo "no se especificó distancia"
    exit 6
fi


echo " event=$event lon=$lon lat=$lat dist=$dist time=$time outfile=$outfile "

psql -d sismoident -c "TRUNCATE TABLE temp_tseries;"

psql -d sismoident -c "\copy (SELECT estacion, to_char(min(lower(tiempo)),'YYMONDD'),
	                                       to_char(max(upper(tiempo)),'YYMONDD')
			      FROM (SELECT h.estacion, t.trango * h.rango as tiempo
			            FROM   estaciones e 
				    JOIN   (VALUES ( st_setsrid(st_makepoint($lon,$lat),4326),
                                                                '$time'::tsrange )) AS t(geog, trango)
				      ON st_DWithin(e.geom,t.geog,'$dist'::integer) 
			            JOIN   http_tiempos h ON e.id = h.estacion 
			            WHERE  t.trango * h.rango != 'empty') a
			            GROUP BY estacion
             	                    HAVING sum(upper(tiempo) - lower(tiempo)) > interval '50 days' 
		                    ORDER BY sum(upper(tiempo) - lower(tiempo)) DESC) 
		       TO STDOUT WITH CSV DELIMITER ' ';" |\
	awk "//{printf \"xzcat %s/%s* | sed -n '/%s/,/%s/p' \n\",\"$DATOS\",\$1,\$2,\$3}" |\
	parallel | grep -v site | sed -E 's/\s+/\t/g' |\
       	psql -d sismoident -c "\copy temp_tseries (estacion, YYMMMDD, anio_decimal, MJD, week, dow, reflon, e0,
					           east, n0, north, u0, up, ant, sig_e, sig_n, sig_u, corr_en,
						   corr_eu, corr_nu) from stdin"


psql -d sismoident -c "UPDATE temp_tseries SET tiempo = tsrange(to_date(yymmmdd,'YYMONDD'),to_date(yymmmdd,'YYMONDD')+1);"

if [ "$outfile" = "-" ]
then
    exit 0
else
    psql -d sismoident -c "\COPY temp_tseries TO STDOUT with CSV DELIMITER '|' HEADER" > "$outfile"
fi

exit 0
