#!/bin/sh

# Esto es para manejar los perminos, absolutamente troglodita.
# Forma correcta: docker con user namespace redirection

sudo chown -R 999:999 /home/javier/doctorado/datos/http-nevada-data

docker run --name sarasa-test -e POSTGRES_PASSWORD=docker \
           -p 127.0.0.1:5432:5432 \
	   -v $(realpath $(dirname $0))/datos:/var/lib/postgresql/sismodb/datos\
           -v /home/javier/doctorado/datos/http-nevada-data:/var/lib/postgresql/sismodb/datos/http-nevada\
	   sarasa

#Idem comentario anterior

sudo chown -R 999:999 /home/javier/doctorado/datos/http-nevada-data
