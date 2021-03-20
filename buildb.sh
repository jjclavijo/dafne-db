#!/bin/bash

for i in $(find ~/sismodb/manejo-datos/ -name '0*.sh' | sort)
do
    echo $i
    bash $i
done
