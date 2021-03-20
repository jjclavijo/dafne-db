#!/bin/bash

# uso: load_event_tseries.sh <id> <distancia [m]> 
# Parsing de argumentos, en principio se permite usar
# evento/distancia o latitud,longitud,tiempo,distancia

# ------------------------------------
# ----- Configuración de entorno -----
# ------------------------------------

# TODO: flexibilizar la configuración mas allá de usar variables de entorno

. $(dirname $0)/setenv.sh

shopt -s expand_aliases
alias psql="psql -h $SI_HOST -p $SI_PORT -U $SI_USER"

export DATOS=$DATOS/http-nevada # http-nevada hardcodeado !!!!!!

# -----------------------------------------
# ----- FIN: Configuración de entorno -----
# -----------------------------------------

# --------------------------------------------------------------
# ------------ Inicio de Procesamiento de Argumentos -----------
# --------------------------------------------------------------

# Credit to https://stackoverflow.com/a/29754866/9296057 Robert Siemmer
# For the option parsing stuff

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

# echo " event=$event lon=$lon lat=$lat dist=$dist time=$time outfile=$outfile "

# ------------------------------------------------------------------------------
# ------------ Hasta aquí Robert Siemmer, Ahora se verifica el evento ----------
# ------------------------------------------------------------------------------

if [ "$dist" = '-' ]
then
    echo "no se especificó distancia"
    exit 6
fi

if [ "$event" = '-' ]
then
    if [ $lat = '-' -o $lon = '-' -o $time = '-' ]
	then
	    echo "Si no se especifica evento se debe especificar latitud longitud y rango."
	    exit 5
    fi
else
    # Notar que aquí ya se está consultando a la base de datos,
    # TODO: Verificar antes si la base está activa
    read lon lat time <<< \
	 $(psql -d sismoident \
		-tAc "SELECT st_x(geog::geometry),
                             st_y(geog::geometry),trango
                      FROM terremotos t WHERE t.ogc_fid=$event" | tr '|' ' ')
fi

# ---------------------------------------------------------------
# ------------Fin de Procesamiento de Argumentos ----------------
# ---------------------------------------------------------------

#DEBUG# echo " event=$event lon=$lon lat=$lat dist=$dist time=$time outfile=$outfile "

# Nos manejamos con tuberias nombradas, para comunicar los procesos auxiliares
# con psql.

#
# El esquema es: se hace una consulta al indice para ver que archivos hay
# que leer, se pasa eso por una tubería a un filtro que después lo distribuye
# a varios procesos que leen los archivos y escriben linea por linea a otra
# tubería.
# Esta segunda tubería la lee psql para cargarla a la base, ordenarla y 
# devolverla a una tercera tubería en forma de tabla con la información
# necesaria, y no mas.
#
# La salida estandard, solo muestra el nombre del fifo al que manda la tabla.

filesfifo=$(mktemp -u)

#DEBUG# echo "Lista de archivos -> $filesfifo"

mkfifo $filesfifo

psql -d sismoident <<SQL  > /dev/null &
CREATE TEMP VIEW archivos_ AS
SELECT estacion, to_char(min(lower(tiempo)),'YYMONDD') inicio,
       to_char(max(upper(tiempo)),'YYMONDD') fin
FROM   (SELECT   h.estacion, t.trango * h.rango as tiempo
        FROM     estaciones e
        JOIN     (VALUES ( st_setsrid(st_makepoint($lon,$lat),4326),
                          '$time'::tsrange )) AS t(geog, trango)
	ON       st_DWithin(e.geom,t.geog,'$dist'::integer)
        JOIN     http_tiempos h ON e.id = h.estacion
        WHERE    t.trango * h.rango != 'empty') a
GROUP BY estacion
HAVING   sum(upper(tiempo) - lower(tiempo)) > interval '50 days'
ORDER BY sum(upper(tiempo) - lower(tiempo)) DESC;
\copy (SELECT * from archivos_) TO $filesfifo WITH CSV DELIMITER ' '
SQL

pid0=$!

#Guardamos el pid por las dudas, aunque este proceso termina si el otro
# termina, cuando leen toda la lista de archivos.

coordsfifo=$(mktemp -u)

mkfifo $coordsfifo

#DEBUG# echo "Coordenadas en -> $coordsfifo"

# Esta es la parte donde la escritura a disco podría fastidiar, usamos un pipe nombrado
awk "//{printf \"xzcat %s/%s* | sed -n '/%s/,/%s/p' \n\",\"$DATOS\",\$1,\$2,\$3}" $filesfifo |\
parallel | grep -v site | sed -E 's/\s+/\t/g' > $coordsfifo &

pid1=$!

#DEBUG# echo "Awk Leyendo en $coordsfifo"
#Guardamos el pid por las dudas, aunque este proceso termina si el otro
# termina, cuando leen toda la lista de coordenadas.

if [ "$outfile" = "-" ]
then
    outfifo=$(mktemp -u)
    mkfifo $outfifo
    out=$outfifo
else
    out=$outfile
fi

echo "Salida en:$out"

psql -d sismoident <<SQL > /dev/null &
CREATE TEMP TABLE temp_tseries_t (estacion varchar,
				  YYMMMDD varchar(7), anio_decimal numeric, MJD integer,
				  week integer, dow integer, reflon numeric, e0 numeric,
				  east numeric, n0 numeric, north numeric, u0 numeric, 
				  up numeric, ant numeric, sig_e numeric, sig_n numeric,
				  sig_u numeric, corr_en numeric, corr_eu numeric, corr_nu numeric
				  );
\copy temp_tseries_t from $coordsfifo
ALTER TABLE temp_tseries_t ADD COLUMN tiempo tsrange;
UPDATE temp_tseries_t SET tiempo = tsrange(to_date(yymmmdd,'YYMONDD'),to_date(yymmmdd,'YYMONDD')+1);
CREATE TEMP VIEW temp_tseries_t_out AS
SELECT DISTINCT estacion,lower(tiempo) + (upper(tiempo)-lower(tiempo))/2 tiempo,
		reflon,e0,east,n0,north,u0,
		up,ant,sig_e,sig_n,sig_u,
		corr_en,corr_eu,corr_nu
FROM   temp_tseries_t;
\copy (SELECT * FROM temp_tseries_t_out) TO $out with CSV DELIMITER '|' HEADER
SQL

pid2=$!

wait $pid2

# Deberíamos manejar con un timeout esto,
# TODO: esperar y si se colgó algo kill y # Salida con error

wait $pid1 #si hubo algun problema se tilda acá
wait $pid0

exit 0
