FROM apache/airflow:2.2.3

ENV AIRFLOW_HOME=/opt/airflow

USER root
RUN apt-get update -qq && apt-get install vim -qqq

# Ref: https://airflow.apache.org/docs/docker-stack/recipes.html

SHELL ["/bin/bash", "-o", "pipefail", "-e", "-u", "-x", "-c"]

RUN mkdir /home/airflow/.ssh
RUN ssh-keygen -t rsa -b 2048 -q -N '' -f /home/airflow/.ssh/id_rsa

WORKDIR $AIRFLOW_HOME
USER $AIRFLOW_UID