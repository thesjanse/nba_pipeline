import os
import logging
import boto3
import json
import pyarrow.csv as pv
import pyarrow.parquet as pq

from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator

from datetime import timedelta, datetime

DATASET = "patrickhallila1994/nba-data-from-basketball-reference"
FOLDER = "/home/airflow/data"
CSV = [
    "boxscore.csv", "coaches.csv", "games.csv",
    "play_data.csv", "player_info.csv", "salaries.csv"
]
NAMES = [n[:-4] for n in CSV]
PARQUET = [n + '.parquet' for n in NAMES]

PY_FOLDER = "/opt/airflow/dags/extra/"
PY = ["transform_nba.py"]

# read tf-output.json string
with open("/home/airflow/tf_output/tf-output.json", "r") as f:
    tf = json.load(f)
DATA_BUCKET = tf["data_bucket"]
DP_BUCKET = tf["dp_bucket"]


def format_to_parquet(src_file):
    """Format csv file to parquet
    Keyword arguments:
        src_file: source file for formatting.
    Returns:
        0 if successful, 1 if there is an error."""
    if not src_file.endswith(".csv"):
        logging.error("Can only accept source files in CSV format")
        return 1
    table = pv.read_csv(src_file)
    pq.write_table(table, src_file.replace(".csv", ".parquet"))
    return 0


def load_to_bucket(file, bucket, key):
    """Upload file to s3 yandex cloud bucket.
    Keyword Arguments:
        file: the path to file.
        bucket: s3 bucket name to upload to.
        key: bucket filepath to upload to.
    Returns:
        0 if successful, 1 if there is an error."""

    session = boto3.session.Session()
    s3 = session.client(
        service_name="s3",
        endpoint_url="https://storage.yandexcloud.net"
    )

    s3.upload_file(file, bucket, key)
    return 0


default_args = {
    "owner": "airflow",
    "start_date": datetime(2022, 4, 3),
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5)
}

dag = DAG(
    dag_id="ingest_to_bucket",
    schedule_interval="00 10 1 * *",
    default_args=default_args,
    catchup=False,
    max_active_runs=1,
    tags=["nba"]
)

download_datasets = BashOperator(
    task_id="download_datasets",
    bash_command=F"""
        kaggle datasets download -d {DATASET} -p {FOLDER} --unzip""",
    dag=dag)


format_files = []
for f, n in zip(CSV, NAMES):
    format_files.append(PythonOperator(
        task_id="format_{0}_to_parquet".format(n),
        python_callable=format_to_parquet,
        op_kwargs={
            "src_file": os.path.join(FOLDER, f),
        },
        dag=dag
    ))

upload_files = []
for f, n in zip(PARQUET, NAMES):
    upload_files.append(PythonOperator(
        task_id=F"upload_{n}",
        python_callable=load_to_bucket,
        op_kwargs={
            "file": os.path.join(FOLDER, f),
            "bucket": DATA_BUCKET,
            "key": f,
        },
        dag=dag
    ))

upload_scripts = []
for f in PY:
    upload_scripts.append(PythonOperator(
        task_id=F"upload_{f[:-3]}",
        python_callable=load_to_bucket,
        op_kwargs={
            "file": os.path.join(PY_FOLDER, f),
            "bucket": DP_BUCKET,
            "key": f
        },
        dag=dag
    ))

finish_formatting = DummyOperator(
    task_id="finish_formatting",
    dag=dag
)

delete_datasets = BashOperator(
    task_id="delete_datasets",
    bash_command=F"rm -r {FOLDER}",
    dag=dag
)

for ff in format_files:
    download_datasets >> ff
format_files >> finish_formatting

for uf in upload_files:
    finish_formatting >> uf
upload_files >> delete_datasets 
upload_scripts >> delete_datasets
