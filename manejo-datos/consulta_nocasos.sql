CREATE TEMP TABLE nocasos AS 
SELECT *
FROM http_tiempos h 
WHERE upper(rango) - lower(rango) > interval '60 days' 
EXCEPT
SELECT h.* from http_tiempos h, http_casos c 
WHERE h.estacion = c.estacion AND h.rango && c.trango;

CREATE INDEX nocasos_rango ON nocasos USING gist(rango);

CREATE TABLE http_no_casos (estacion varchar(4) references http_estaciones (id), rango tsrange, fin text, dias integer);

INSERT INTO http_no_casos (estacion, rango, fin)
SELECT estacion,rango,fin FROM nocasos EXCEPT
SELECT distinct n.estacion, n.rango, n.fin FROM nocasos n JOIN terremotos t ON t.time <@ n.rango AND t.mag > 7.2;

UPDATE http_no_casos SET dias = EXTRACT (day FROM upper(rango) - lower(rango));
ALTER TABLE http_no_casos ADD COLUMN iid serial PRIMARY KEY;
