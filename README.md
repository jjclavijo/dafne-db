# The dafne Dataset Database

CITE Note:

This work is part of my Phd research, hopefully soon here will be a proper paper
to cite. Meanwhile, please cite this repo.

## What is dafne

Dafne stands for *Displacement As Features on NEural NEtworks*, and is a
research project, part of my (Javier J. Clavijo) Phd research at FI, Universidad de Buenos Aires.

Data analisys is in progres, using GNSS coordinates timeseries and seismic event
data.

## What is the dataset

The dataset consists on GNSS Coordinates from http://geodesy.unr.edu, and
earthquake data from USGS. After some data manipulation, a set of data segments
is compiled, along with labels for posible seismic events affecting the observation.

Methods, results and analisys will soon be published.

## Branches

The main (this) branch contains the first version of the full dataset slicing
and selection process, look into the Makefile,Dockerfile and scripts for
better understanding.

For instructions on data downloading please refer to the data provider site or
to http://github.com/jjclavijo/dafne-db-data

The "empty" Branch provides scripts for building a version of the database
with no coordinate data. Instead, it has data availability informaition, which
combined with spatial informaition is enought for data indexing and selection.

The "full" Branch includes the dataset loaded into the database, which integrates
with the rest of the dataset generating workflow.
