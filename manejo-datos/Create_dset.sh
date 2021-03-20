#!/bin/bash

. $(dirname $0)/setenv.sh
. ~/envs/tmppsql/bin/activate

sidb_create_dset
