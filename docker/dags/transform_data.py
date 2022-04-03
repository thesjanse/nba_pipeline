import json

from airflow import DAG
from airflow.sensors.external_task_sensor import ExternalTaskSensor
from airflow.providers.yandex.operators.yandexcloud_dataproc import (
    DataprocCreateClusterOperator,
    DataprocCreatePysparkJobOperator,
    DataprocDeleteClusterOperator
)
from datetime import timedelta, datetime

# read tf-output.json string
with open("/home/airflow/tf_output/tf-output.json", "r") as f:
    tf = json.load(f)

# read ssh public key
with open("/home/airflow/.ssh/id_rsa.pub", "r") as f:
    ssh = f.readlines()

CLUSTER_NAME = "dataproc-cluster"
CLUSTER_DESC = "Dataproc Spark Cluster"
SERVICES = ("HDFS", "SPARK", "YARN")
PYTHON_FILE = F"s3a://{tf['dp_bucket']}/transform_nba.py"


default_args = {
    "owner": "airflow",
    "start_date": datetime(2022, 4, 3),
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5)
}


dag = DAG(
    dag_id="transform_nba_data",
    schedule_interval="00 10 1 * *",
    default_args=default_args,
    catchup=False,
    max_active_runs=1,
    tags=["nba"]
)

wait_ingestion = ExternalTaskSensor(
    task_id="wait_ingestion",
    external_dag_id="ingest_to_bucket",
    external_task_id="delete_datasets",
    mode="reschedule",
    dag=dag
)

create_cluster = DataprocCreateClusterOperator(
    task_id="create_spark_cluster",
    zone=tf["zone"],
    s3_bucket=tf["dp_bucket"],
    folder_id=tf["folder_id"],
    cluster_name=CLUSTER_NAME,
    cluster_description=CLUSTER_DESC,
    ssh_public_keys=ssh[0],
    subnet_id=tf["subnet_id"],
    services=SERVICES,
    service_account_id=tf["dp_sa_id"],

    masternode_resource_preset="s2.micro",
    masternode_disk_size=20,
    masternode_disk_type="network-ssd",
    datanode_resource_preset="s2.small",
    datanode_disk_size=20,
    datanode_disk_type="network-hdd",
    datanode_count=1,
    computenode_resource_preset="s2.small",
    computenode_disk_size=20,
    computenode_disk_type="network-hdd",
    computenode_count=1,
    dag=dag
)

transform_nba = DataprocCreatePysparkJobOperator(
    task_id="transform_nba",
    main_python_file_uri=PYTHON_FILE,
    args=[
        tf["ch_cluster_id"],
        tf["ch_db_name"],
        tf["ch_user"],
        tf["ch_pass"],
        tf["data_bucket"]
    ],
    dag=dag
)

delete_cluster = DataprocDeleteClusterOperator(
    task_id="delete_spark_cluster",
    dag=dag
)

create_cluster >> transform_nba >> delete_cluster
