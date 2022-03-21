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