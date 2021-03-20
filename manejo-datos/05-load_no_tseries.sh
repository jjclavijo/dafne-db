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
	   -c "CREATE TABLE IF NOT EXISTS http_tseries 
                            (estacion varchar REFERENCES http_estaciones (id),
		             YYMMMDD varchar(7), anio_decimal numeric, MJD integer,
		             week integer, dow integer, reflon numeric, e0 numeric,
		             east numeric, n0 numeric, north numeric, u0 numeric, 
		             up numeric, ant numeric, sig_e numeric, sig_n numeric,
			     sig_u numeric, corr_en numeric, corr_eu numeric, 
                             corr_nu numeric);"\
	   -c "CREATE UNIQUE INDEX IF NOT EXISTS ht_ey ON http_tseries (estacion,yymmmdd);"

linesfifo=$(mktemp -u)
mkfifo $linesfifo

psql -d sismoident -c "\copy (SELECT estacion, fin, dias 
                              FROM http_no_casos ) 
		       TO STDOUT WITH CSV DELIMITER ' ';" |\
	awk "//{printf \"xzgrep -m 1 -B %s %s %s/%s*\n\",\$3,\$2,\"$DATOS\",\$1}" |\
	parallel --bar | grep -v site | sed -nE '/^.... ....... / {s/\s+/\t/g;p}' \
        > $linesfifo &
# dias -1 era un bug, el intervalo dura dias desde el inicio al fin.
pid0=$!

psql -d sismoident <<EOSQL
-- Query for loading data
CREATE TEMP TABLE http_tseries_t 
                  (estacion varchar,
		   YYMMMDD varchar(7), anio_decimal numeric, MJD integer,
		   week integer, dow integer, reflon numeric, e0 numeric,
		   east numeric, n0 numeric, north numeric, u0 numeric, 
		   up numeric, ant numeric, sig_e numeric, sig_n numeric,
		   sig_u numeric, corr_en numeric, corr_eu numeric, 
                   corr_nu numeric);
\copy http_tseries_t FROM $linesfifo;
INSERT INTO http_tseries 
SELECT * FROM http_tseries_t
ON CONFLICT DO NOTHING
EOSQL

# Depercated view
#psql -d sismoident -c "UPDATE http_no_tseries SET tiempo = tsrange(to_date(yymmmdd,'YYMONDD'),to_date(yymmmdd,'YYMONDD')+1) WHERE tiempo IS NULL;"
#
#psql -d sismoident -c " CREATE VIEW no_tseries_out AS
#			SELECT DISTINCT t.estacion,t.tiempo,t.reflon,t.e0,t.east,t.n0,t.north,t.u0,
#					t.up,t.ant,t.sig_e,t.sig_n,t.sig_u,
#					t.corr_en,t.corr_eu,t.corr_nu,c.iid
#			FROM http_no_tseries t 
#			JOIN http_no_casos c 
#			ON t.estacion = c.estacion AND t.tiempo && c.rango;"
			
#psql -d sismoident -c "\COPY no_tseries_out TO STDOUT with csv delimiter '|' header"
psql -d sismoident <<EOSQL
CREATE MATERIALIZED VIEW indice_nc AS 
SELECT estacion,iid,
      to_char(generate_series(-dias,0)+to_date(fin,'YYMONDD'),'YYMONDD') yymmmdd,
      generate_series(0,dias)/61 ch 
FROM http_no_casos;

CREATE INDEX in_ey ON indice_nc (estacion,yymmmdd);
-- CREATE INDEX in_eic ON indice_nc (estacion,iid,ch);
CREATE INDEX in_eic ON indice_nc (iid,ch);

CREATE MATERIALIZED VIEW indice_nc_chiid AS
SELECT iid, ch , ROW_NUMBER () OVER (ORDER BY iid,ch) chiid
FROM (SELECT DISTINCT iid, ch FROM indice_nc) as a;

CREATE INDEX inc_chiid ON indice_nc_chiid (iid,ch);

--CREATE INDEX ht_ey ON http_tseries (estacion,yymmmdd);

EOSQL

# for python:
#QUERY = """
#SELECT max(estacion) estacion, iid, ch, array_agg(to_date(i.yymmmdd,'YYMONDD')) tiempo,
#          array_agg(north) norte, array_agg(east) este, array_agg(up) altura
#  FROM indice_nc i
#  LEFT JOIN http_tseries t USING (estacion, yymmmdd) 
#  JOIN indice_nc_chiid USINC (iid,ch)
#  GROUP BY (iid, ch) HAVING chiid @> int4range(%s,%s);
#"""
