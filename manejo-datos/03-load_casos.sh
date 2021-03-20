#/bin/bash

. $(dirname $0)/setenv.sh

shopt -s expand_aliases

if [ -z ${SI_HOST+x} ]
then
alias psql="psql -U $SI_USER"
else
alias psql="psql -h $SI_HOST -p $SI_PORT -U $SI_USER"
fi

psql -d sismoident -f $(dirname $0)/consulta_casos.sql -f $(dirname $0)/consulta_nocasos.sql
