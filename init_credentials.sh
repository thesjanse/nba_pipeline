#!/usr/bin/env bash

echo "[default]" > ./credentials/object_storage/config
echo "[default]" > ./credentials/object_storage/credentials
cd terraform
terraform refresh

# write zone to config file
region=$(terraform output zone)
echo "region = "$region | sed 's/"//g' >> ../credentials/object_storage/config

# write key to credentials file
key_id=$(terraform output object_storage_sa_access_key)
access_key=$(terraform output object_storage_sa_secret_key)
echo "aws_access_key_id = "$key_id | sed 's/"//g' >> ../credentials/object_storage/credentials
echo "aws_secret_access_key = "$access_key | sed 's/"//g' >> ../credentials/object_storage/credentials

# save additional output variables
folder_id=$(terraform output folder_id)
data_bucket=$(terraform output data_bucket_name)
dp_bucket=$(terraform output dp_bucket_name)
subnet_id=$(terraform output dp_subnet_id)
dp_sa_id=$(terraform output dp_sa_id)
ch_cluster_id=$(terraform output clickhouse_cluster_id)
ch_db_name=$(terraform output clickhouse_db_name)
ch_user=$(terraform output clickhouse_username)
ch_pass=$(terraform output clickhouse_password)

# generate json string for dataproc airflow
JSON='{
    "zone": %s,
    "folder_id": %s,
    "data_bucket": %s,
    "dp_bucket": %s,
    "subnet_id": %s,
    "dp_sa_id": %s,
    "ch_cluster_id": %s,
    "ch_db_name": %s,
    "ch_user": %s,
    "ch_pass": %s
}'
cd ../credentials/
mkdir -p tf_output
printf "$JSON" "$region" "$folder_id" "$data_bucket" "$dp_bucket" "$subnet_id" "$dp_sa_id" "$ch_cluster_id" "$ch_db_name" "$ch_user" "$ch_pass" > ./tf_output/tf-output.json

# generate json credentials for dataproc
mkdir -p yandex
yc iam key create --service-account-id $(echo $dp_sa_id | sed 's/"//g') --output ./yandex/yandex_credentials.json