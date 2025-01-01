
## 1-介绍

**1)-What?**

一个可以扩展的 `Python` `workflow` 框架.  `Python` 的特性可以让他高度可扩展.



```python
from datetime import datetime

from airflow import DAG
from airflow.decorators import task
from airflow.operators.bash import BashOperator

# A DAG represents a workflow, a collection of tasks
with DAG(dag_id="demo", start_date=datetime(2022, 1, 1), schedule="0 0 * * *") as dag:
    # Tasks are represented as operators
    hello = BashOperator(task_id="hello", bash_command="echo hello")

    @task()
    def airflow():
        print("airflow")

    # Set dependencies between tasks
    hello >> airflow()
```

## refer
- [homepage](https://airflow.apache.org/)
- [docs](https://airflow.apache.org/docs/apache-airflow/stable/index.html)