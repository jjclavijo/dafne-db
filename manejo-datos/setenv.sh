#Este archivo esta pensado para Sourcearlo, si se ejecuta falla

#chequeamos si el archivo fue sourceado
(return 2>/dev/null) && sourced=1 || { echo "Modo de uso: <<. setenv.sh>>" && exit; }

base=$(dirname $0)/..

export DATOS=$base/datos
export SI_BASE=sismoident
export SI_USER=postgres
#export SI_HOST=localhost
#export SI_PORT=5432
export SI_PASS=docker

MY_PATH="`dirname \"$BASH_SOURCE\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
if [ -z "$MY_PATH" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi
echo "$MY_PATH"

export PGPASSFILE=$(cd "$MY_PATH" && readlink -f .pgpass)

if [ -z ${SI_HOST+x} ]
then
alias "d.psql"="psql -U $SI_USER $SI_BASE"
else
alias "d.psql"="psql -h $SI_HOST -p $SI_PORT -U $SI_USER $SI_BASE"
fi
