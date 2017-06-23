

from airflow import DAG
from airflow.operators.bash_operator import BashOperator
from datetime import datetime, timedelta


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime.today() - timedelta(minutes=30),
    'email': ['airflow@example.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    }

dag = DAG(
    'smoke_test', default_args=default_args, schedule_interval='*/2 * * * *',
    catchup=False)

t1 = BashOperator(
    task_id='print_date',
    bash_command='date',
    dag=dag)

