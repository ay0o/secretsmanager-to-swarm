import base64
import json
import os
import boto3
import requests


def get_aws_secret(secret_arn):
    session = boto3.session.Session()
    client = session.client('secretsmanager', endpoint_url=os.environ['secretsmanager_endpoint'])
    response = client.get_secret_value(SecretId=secret_arn)
    secret_name = response['Name']
    secret_data = json.loads(response['SecretString'])
    return secret_name, secret_data


def report_docker_error(data):
    raise SystemExit(f"Code: {data.status_code} - {data.json()}")


def create_docker_secret(name, value):
    url = f"{os.environ['docker_endpoint']}/secrets/create"
    payload = {"Name": name, "Data": value}
    response = requests.post(url, json=payload)
    if response.status_code != 201:
        report_docker_error(response)

def check_if_docker_secret_exists(name):
    url = f"{os.environ['docker_endpoint']}/secrets?filters=%7B%22name%22%3A%5B%22{name}%22%5D%7D"
    response = requests.get(url)
    if response.status_code == 200 and len(response.json()) > 0:
        return True
    return False


def handler(event, context):
    aws_secret_name, aws_secret_data = get_aws_secret(event['detail']['responseElements']['arn'])

    for key, value in aws_secret_data.items():
        secret_name = f"{aws_secret_name}_{key}"
        if event['detail']['eventName'] == 'PutSecretValue':
            if check_if_docker_secret_exists(secret_name):
                print(f"[WARNING] Secret {secret_name} already exists. Skipping.")
                continue
        secret_value = base64.b64encode(value.encode('ascii'))
        create_docker_secret(secret_name, secret_value)
