# VERSION 1.10.9
# AUTHOR: Matthieu "Puckel_" Roisil
# ORIGINAL_MAINTENAR: Puckel_
# SOURCE: https://github.com/puckel/docker-airflow

FROM python:3.7-slim-buster
LABEL maintainer="johnleonrd_CO"

# Never prompt the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux
# Airflow
# dockerfile initial airflow creation verions = 1.10.9 should you decide to downgrade or upgrade.
# latest version as of 12 May 2020 1.10.10
ARG AIRFLOW_VERSION=1.10.10
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}
ENV AIRFLOW__CORE__BASE_LOG_FOLDER=${AIRFLOW_USER_HOME}/logs
# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8
# Disable noisy "Handling signal" log messages:
ENV GUNICORN_CMD_ARGS --log-level WARNING

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get -y install sudo \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        postgresql \
        systemd \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow && adduser --disabled-password --gecos '' airflow sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
#    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow && echo "airflow:airflow" | chpasswd && adduser airflow sudo \
    && pip install -U pip setuptools wheel \
    && pip install apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

# Add the neccessary files to container
COPY ./entrypoint.sh /entrypoint.sh
COPY ./airflow.cfg  ${AIRFLOW_USER_HOME}/airflow.cfg
COPY ./dags/ /usr/local/airflow/dags/

# Change AIRFLOW_USER_HOME  owner
RUN chown -R airflow: ${AIRFLOW_USER_HOME}

EXPOSE 8080 5555 8793 5432

# install requirements
ADD requirements.txt /src/requirements.txt
RUN pip3 install -r /src/requirements.txt --no-cache-dir

USER airflow
# set starting working dir to airflow home
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]

# simply start apache webserver which will run -> initdb and scheduler in one container
# if the executor = SequentialExecutor or LocalExecutor
# this project used -> SequentialExecutor
CMD ["webserver"]
