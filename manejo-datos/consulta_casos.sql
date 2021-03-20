CREATE TABLE terremotos AS 
SELECT *, tsrange(time - interval '30 days',time + interval '30 days') trango 
FROM (SELECT ogc_fid,mag,to_timestamp(time/1000.) AT TIME ZONE 'UTC' AS time,
	     geog from usgs_sismos) t;

CREATE INDEX http_estaciones_geography ON http_estaciones USING gist(geom);
CREATE INDEX http_tiempos_rango ON http_tiempos USING gist(rango);
CREATE INDEX terremotos_geog ON terremotos USING gist(geog);
CREATE INDEX terremotos_trango ON terremotos USING gist(trango);

ALTER TABLE terremotos ADD CONSTRAINT unique_ogcid UNIQUE (ogc_fid);

CREATE TABLE http_casos (estacion VARCHAR(4) REFERENCES http_estaciones (id), sid integer REFERENCES terremotos (ogc_fid), trango tsrange);

CREATE INDEX http_casos_est_sid ON http_casos USING btree (estacion, sid);

INSERT INTO http_casos 
SELECT t.estacion,s.ogc_fid,t.rango * s.trango 
FROM terremotos s 
JOIN http_estaciones e ON ST_DWithin(s.geog,e.geom,1000000,True) 
JOIN http_tiempos t ON t.rango && s.trango AND t.estacion = e.id 
WHERE s.mag > 7.5;
INSERT INTO http_casos 
SELECT t.estacion,s.ogc_fid,t.rango * s.trango 
FROM terremotos s 
JOIN http_estaciones e ON ST_DWithin(s.geog,e.geom,400000,True) 
JOIN http_tiempos t ON t.rango && s.trango AND t.estacion = e.id 
WHERE s.mag > 7 AND s.mag <= 7.5;
INSERT INTO http_casos 
SELECT t.estacion,s.ogc_fid,t.rango * s.trango 
FROM terremotos s 
JOIN http_estaciones e ON ST_DWithin(s.geog,e.geom,100000,True) 
JOIN http_tiempos t ON t.rango && s.trango AND t.estacion = e.id 
WHERE s.mag > 6.5 AND s.mag <= 7;
INSERT INTO http_casos 
SELECT t.estacion,s.ogc_fid,t.rango * s.trango 
FROM terremotos s 
JOIN http_estaciones e ON ST_DWithin(s.geog,e.geom,50000,True) 
JOIN http_tiempos t ON t.rango && s.trango AND t.estacion = e.id 
WHERE s.mag > 6 AND s.mag <= 6.5 ;

-- Create a mapping because we need an integer identifier for partitioning
/*
CREATE TABLE estacion_sid_map (iid serial PRIMARY KEY, estacion VARCHAR(4) REFERENCES http_estaciones (id), sid integer REFERENCES terremotos (ogc_fid));
INSERT INTO estacion_sid_map
SELECT DISTINCT estacion,sid
FROM http_casos;
*/

/* Test de los casos cargados.
SELECT estacion, sid,sum( upper(trango) - lower(trango)) 
FROM http_casos 
GROUP BY estacion, sid 
HAVING sum(upper(trango) - lower(trango)) > interval '50 days' 
ORDER BY sum DESC;
*/
