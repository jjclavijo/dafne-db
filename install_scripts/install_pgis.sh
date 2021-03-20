#!/bin/bash

# Bash "strict mode", to help catch problems and bugs in the shell
# script. Every bash script you write should include this. See
# http://redsymbol.net/articles/unofficial-bash-strict-mode/ for
# details.
set -euo pipefail

# Tell apt-get we're never going to be able to give manual
# feedback:
export DEBIAN_FRONTEND=noninteractive

# Update the package listing, so we know what package exist:
apt-get update

# Install security updates:
apt-get -y upgrade

CERT_DEPS="gnupg2 wget ca-certificates rpl pwgen"

# Install a new package, without unnecessary recommended packages:
apt-get -y install --no-install-recommends $CERT_DEPS

sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update && apt-get install -y --no-install-recommends postgresql-12-postgis-3 parallel

apt-get -y autoremove $CERT_DEPS

# Delete cached files we don't need anymore:
apt-get clean
rm -rf /var/lib/apt/lists/*
