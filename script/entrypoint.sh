#!/usr/bin/env bash

CMD="airflow"
TRY_LOOP="10"
MYSQL_HOST="mysql"
MYSQL_PORT="3306"
MYSQL_USER="airflow"
MYSQL_PASSWORD="airflow"
MYSQL_DATABASE="airflow"
SLURM_HOST="slurm-master"
FERNET_KEY=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print FERNET_KEY")

# Generate Fernet key
sed -i "s/\\\$FERNET_KEY/${FERNET_KEY}/" $AIRFLOW_HOME/airflow.cfg

# Start munged
if [[ -f /root/munge-key/munge.key ]]; then
    cat /root/munge-key/munge.key > /etc/munge/munge.key
fi
runuser -u munge munged

# try building Airflow from source if needed
if [[ -f /usr/local/airflow/src/setup.py ]]; then
    pushd /usr/local/airflow/src
    pip uninstall -y airflow flask-wtf
    pip install -e .[drmaa] || exit 1
    popd
fi

mysql_ready() {
  if ! nc $MYSQL_HOST $MYSQL_PORT >/dev/null 2>&1 </dev/null; then
      return 1
  fi
  [ "$@" = "webserver" ] && return 0
  mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD \
	-D $MYSQL_DATABASE \
	-e 'SHOW TABLES;' | grep -q 'dag_run'
}

# wait for DB
if [ "$@" = "webserver" ] || [ "$@" = "worker" ] || [ "$@" = "scheduler" ] ; then
  i=0
  while ! mysql_ready "$@"; do
    i=`expr $i + 1`
    if [ $i -ge $TRY_LOOP ]; then
      echo "$(date) - ${MYSQL_HOST}:${MYSQL_PORT} still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for ${MYSQL_HOST}:${MYSQL_PORT}... $i/$TRY_LOOP"
    sleep 5
  done
  if [ "$@" = "webserver" ]; then
    echo "Initialize database..."
    $CMD initdb
    echo "Install smoke test DAG..."
    cp -v smoke_test.py dags/
  fi
  sleep 5
fi

# wait for SLURM
#if python -c "import socket; socket.gethostbyname('$SLURM_HOST')" 2>/dev/null; then
#  i=0
#  while ! squeue; do
#    i=`expr $i + 1`
#    if [ $i -ge $TRY_LOOP ]; then
#      echo "$(date) - SLURM still not reachable, giving up"
#      exit 1
#    fi
#    echo "$(date) - waiting for SLURM... $i/$TRY_LOOP"
#    sleep 5
#  done
#else
#  echo "$(date) - SLURM host not found, skipping"
#fi

if [ "$@" = "bash" ]; then
  exec /bin/bash
elif [ "$1" = "unittest" ]; then
  shift
  TESTCASE="$@"
  [[ -z $TESTCASE ]] && TESTCASE="tests.core:CoreTest"
  cd /usr/local/airflow/src
  pip install -e .[devel,postgres,hive] || exit 1
  ./run_unit_tests.sh $TESTCASE -s --logging-level=DEBUG
elif [ "$@" = "slurm-master" ]; then
  slurmd -D -vvvvv &
  sleep 2
  slurmctld -D -vvvvv
else
  runuser -u airflow $CMD "$@"
fi
