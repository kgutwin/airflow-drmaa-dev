#!/usr/bin/env bash

CMD="airflow"
TRY_LOOP="10"
MYSQL_HOST="mysql"
MYSQL_PORT="3306"
MYSQL_USER="airflow"
MYSQL_PASSWORD="airflow"
MYSQL_DATABASE="airflow"
#RABBITMQ_HOST="rabbitmq"
#RABBITMQ_CREDS="airflow:airflow"
FERNET_KEY=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print FERNET_KEY")

# Generate Fernet key
sed -i "s/{FERNET_KEY}/${FERNET_KEY}/" $AIRFLOW_HOME/airflow.cfg

## wait for rabbitmq
#if [ "$@" = "webserver" ] || [ "$@" = "worker" ] || [ "$@" = "scheduler" ] || [ "$@" = "flower" ] ; then
#  j=0
#  while ! curl -sI -u $RABBITMQ_CREDS http://$RABBITMQ_HOST:15672/api/whoami |grep '200 OK'; do
#    j=`expr $j + 1`
#    if [ $j -ge $TRY_LOOP ]; then
#      echo "$(date) - $RABBITMQ_HOST still not reachable, giving up"
#      exit 1
#    fi
#    echo "$(date) - waiting for RabbitMQ... $j/$TRY_LOOP"
#    sleep 5
#  done
#fi

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

exec $CMD "$@"
