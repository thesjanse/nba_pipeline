import os
import logging
import pyarrow.csv as pv
import pyarrow.parquet as pq

from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator

DATASET = "patrickhallila1994/nba-data-from-basketball-reference"
FOLDER = "/home/airflow/data"
FILES = [
    "boxscore.csv", "coaches.csv", "games.csv",
    "play_data.csv", "player_info.csv", "salaries.csv"
]
NAMES = [n[:-4] for n in FILES]


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


default_args = {
    "owner": "airflow",
    "start_date": days_ago(1),
    "depends_on_past": False,
    "retries": 1,
}

dag = DAG(
    dag_id="ingest_to_bucket",
    schedule_interval="@once",
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
for f, n in zip(FILES, NAMES):
    format_files.append(PythonOperator(
        task_id="format_{0}_to_parquet".format(n),
        python_callable=format_to_parquet,
        op_kwargs={
            "src_file": os.path.join(FOLDER, f),
        },
        dag=dag
    ))

finish_dummy = DummyOperator(
    task_id="finish",
    dag=dag
)

for ff in format_files:
    download_datasets >> ff
format_files >> finish_dummy
