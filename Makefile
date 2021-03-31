#HTTP_PROXY=http://proxylh.fi.uba.ar:8080
#HTTPS_PROXY=http://proxylh.fi.uba.ar:8080
TAG="dafne-db"
VERSION="dset-latest"

export SHELL:=/bin/bash
export SHELLOPTS:=$(if $(SHELLOPTS),$(SHELLOPTS):)pipefail:errexit

.ONESHELL:

default: build

.PHONY: check-env
check-env:
ifndef DAFNE_HOME
	$(error DAFNE_HOME not set)
endif

.PHONY: test
build: 
	$(MAKE) build-db

build-db: docker-initpoint.sh
	docker build . -t ${TAG}:${VERSION}

docker-initpoint.sh:
ifdef HTTPS_PROXY
	curl -x ${HTTPS_PROXY} -L https://github.com/docker-library/postgres/raw/master/12/docker-entrypoint.sh -o $@.tmp
else
	curl -L https://github.com/docker-library/postgres/raw/master/12/docker-entrypoint.sh -o $@.tmp
endif
	sed '/exec \"\$$\@\"/d' $@.tmp > $@
	rm $@.tmp
