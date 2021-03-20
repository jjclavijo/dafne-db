#/bin/bash!

. $(dirname $0)/setenv.sh

shopt -s expand_aliases

if [ -z ${SI_HOST+x} ]
then
alias psql="psql -U $SI_USER"
else
alias psql="psql -h $SI_HOST -p $SI_PORT -U $SI_USER"
fi

export DATOS=$DATOS/http-nevada

psql -d sismoident \
	   -c "CREATE TABLE IF NOT EXISTS http_tseries (estacion varchar REFERENCES http_estaciones (id),
					  YYMMMDD varchar(7), anio_decimal numeric, MJD integer,
				          week integer, dow integer, reflon numeric, e0 numeric,
					  east numeric, n0 numeric, north numeric, u0 numeric, 
					  up numeric, ant numeric, sig_e numeric, sig_n numeric,
					  sig_u numeric, corr_en numeric, corr_eu numeric, corr_nu numeric);"\
	   -c "CREATE UNIQUE INDEX IF NOT EXISTS ht_ey ON http_tseries (estacion,yymmmdd);"


linesfifo=$(mktemp -u)
mkfifo $linesfifo

psql -d sismoident -c "\copy (SELECT estacion, to_char(max(upper(trango)),'YYMONDD') 
                              FROM http_casos GROUP BY estacion, sid 
			      HAVING sum(upper(trango) - lower(trango)) > interval '50 days' 
			      ORDER BY sum(upper(trango) - lower(trango)) DESC) 
		       TO STDOUT WITH CSV DELIMITER ' ';" |\
	awk "//{printf \"xzgrep -m 1 -B 60 %s %s/%s*\n\",\$2,\"$DATOS\",\$1}" |\
	parallel --bar | grep -v site | sed -nE '/^.... ....... / {s/\s+/\t/g;p}' \
        > $linesfifo &

pid0=$!

psql -d sismoident <<EOSQL
-- Query for loading data
CREATE TEMP TABLE http_tseries_t (estacion varchar,
					  YYMMMDD varchar(7), anio_decimal numeric, MJD integer,
				          week integer, dow integer, reflon numeric, e0 numeric,
					  east numeric, n0 numeric, north numeric, u0 numeric, 
					  up numeric, ant numeric, sig_e numeric, sig_n numeric,
					  sig_u numeric, corr_en numeric, corr_eu numeric, corr_nu numeric);
\copy http_tseries_t FROM $linesfifo;
INSERT INTO http_tseries 
SELECT * FROM http_tseries_t
ON CONFLICT DO NOTHING;
EOSQL

wait $pid0 #para verificar que termine de escribir

#Para produccion: Archivos ya insertados por completo deberán ser seguidos para evitar trabajo extra cada vez.
#En caso de servir los datos directamente hay que tener la serie cargada completa en http_tseries y olvidarse de
#Los archivos de entrada.

# Este update es sumamente costoso u no aporta en realidad
#psql -d sismoident -c "UPDATE http_tseries SET tiempo = tsrange(to_date(yymmmdd,'YYMONDD'),to_date(yymmmdd,'YYMONDD')+1) WHERE tiempo IS NULL;"

# Vista obsoleta
#psql -d sismoident -c " CREATE VIEW tseries_out AS
#			SELECT DISTINCT t.estacion,t.tiempo,t.reflon,t.e0,t.east,t.n0,t.north,t.u0,
#					t.up,t.ant,t.sig_e,t.sig_n,t.sig_u,
#					t.corr_en,t.corr_eu,t.corr_nu,c.sid,s.time
#			FROM http_tseries t 
#			JOIN (SELECT estacion,sid,tsrange(min(lower(trango)),max(upper(trango))) 
#			      FROM http_casos 
#			      GROUP BY estacion, sid 
#			      HAVING sum(upper(trango) - lower(trango)) > interval '50 days' 
#			      ORDER BY sum(upper(trango) - lower(trango)) DESC) c 
#			ON t.estacion = c.estacion AND t.tiempo && c.tsrange
#			JOIN usgs_sismos s ON c.sid = s.ogc_fid;"
			
#psql -d sismoident -c "\COPY tseries_out TO STDOUT with csv delimiter '|' header"

psql -d sismoident <<EOSQL
-- Filter to short segments and merge interrupted ones.
CREATE VIEW httpc AS 
SELECT sid,estacion,(to_timestamp(t.time/1000.) AT TIME ZONE 'UTC')::date  tiempo, 
       ROW_NUMBER () OVER (ORDER BY random()) as iid
FROM (SELECT sid,estacion 
      FROM http_casos 
      GROUP BY sid,estacion 
      HAVING sum(upper(trango)-lower(trango)) > interval '50 days') AS i
JOIN usgs_sismos t on i.sid=t.ogc_fid;

CREATE MATERIALIZED VIEW indice_c AS 
SELECT e.estacion, e.sid, e.iid,
       to_char(generate_series(-30,30) * '1 day'::interval + e.tiempo,'YYMONDD') AS yymmmdd 
FROM httpc AS e;

CREATE INDEX ic_ey ON indice_c (estacion,yymmmdd);

-- CREATE INDEX ic_eic ON indice_c (estacion,sid,iid);
CREATE INDEX ic_eic ON indice_c (iid);

CREATE INDEX hc_ey ON http_tseries (estacion,yymmmdd);
EOSQL

# for python:
#QUERY = """
#SELECT a.*, s.time
#FROM
#  (SELECT max(estacion) estacion, max(sid) sid, array_agg(to_date(i.yymmmdd,'YYMONDD')) tiempo,
#          array_agg(north) norte, array_agg(east) este, array_agg(up) altura
#  FROM indice_c i
#  LEFT JOIN http_tseries t USING (estacion, yymmmdd)
#  GROUP BY iid) AS a
#JOIN usgs_sismos s ON a.sid = s.ogc_fid;
# """
