# VERSION 1.8.1
# DESCRIPTION: Basic Airflow container
# FORKED from https://github.com/camilb/docker-airflow

FROM debian:jessie

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux
ENV AIRFLOW_PKG airflow
ENV AIRFLOW_VERSION 1.8.0
ENV AIRFLOW_HOME /usr/local/airflow

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8
ENV LC_ALL  en_US.UTF-8

RUN echo "deb http://http.debian.net/debian jessie-backports main" >/etc/apt/sources.list.d/backports.list \
    && apt-get update -yqq \
    && apt-get install -yqq --no-install-recommends \
    apt-utils\
    netcat \
    curl \
    python-pip \
    python-dev \
    mysql-client libmysqlclient-dev \
    libkrb5-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    libxml2-dev libxslt-dev libz-dev \
    build-essential \
    locales \
    && apt-get install -yqq -t jessie-backports python-requests \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow \
    && pip install pytz==2015.7 \
    && pip install cryptography \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install ${AIRFLOW_PKG}==${AIRFLOW_VERSION} \
    && pip install ${AIRFLOW_PKG}[mysql]==${AIRFLOW_VERSION} \
    && pip install ${AIRFLOW_PKG}[async]==${AIRFLOW_VERSION} \
    && pip install ${AIRFLOW_PKG}[ldap]==${AIRFLOW_VERSION} \
    && pip install ${AIRFLOW_PKG}[password]==${AIRFLOW_VERSION} \
    && pip install ${AIRFLOW_PKG}[s3]==${AIRFLOW_VERSION} \
    && pip install ${AIRFLOW_PKG}[slack]==${AIRFLOW_VERSION} \
    && apt-get remove --purge -yqq build-essential python-pip python-dev libmysqlclient-dev libkrb5-dev libsasl2-dev libssl-dev libffi-dev \
    && apt-get clean \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/man \
    /usr/share/doc \
    /usr/share/doc-base

ADD script/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh
ADD config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
ADD dags/smoke_test.py ${AIRFLOW_HOME}/smoke_test.py

RUN \
    chown -R airflow: ${AIRFLOW_HOME} \
    && chmod +x ${AIRFLOW_HOME}/entrypoint.sh

EXPOSE 8080 5555 8793

USER airflow
WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ["./entrypoint.sh"]
