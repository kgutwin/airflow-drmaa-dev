#!/bin/sh

docker run -ti --rm -v ~/github/incubator-airflow:/usr/local/airflow/src \
       kgutwin/airflow-drmaa-dev \
       unittest "$@"
