import base64
import json
import os
import boto3
import requests


try:
    secrets_manager_endpoint = os.environ['secretsmanager_endpoint']
    docker_endpoint = os.environ['docker_endpoint']
except KeyError as e:
    raise SystemExit(f"[ERROR] Missing required variable: {e}")


def get_aws_secret(secret_arn):
    try:
        client = boto3.client('secretsmanager', endpoint_url=secrets_manager_endpoint)
        response = client.get_secret_value(SecretId=secret_arn)
        secret_name = response['Name']
        secret_data = json.loads(response['SecretString'])
        return secret_name, secret_data
    except Exception as e:
        raise SystemExit(f"[ERROR] Could not retrieve AWS secret. Details: {e}")


def create_docker_secret(name, value):
    url = f"{docker_endpoint}/secrets/create"
    payload = {"Name": name, "Data": value}
    try:
        response = requests.post(url, json=payload)
        if response.status_code != 201:
            raise SystemExit(f"[ERROR] Docker secret was not created. Expected 201, got {response.status_code}")
    except requests.RequestException as e:
        raise SystemExit(f"[ERROR] Could not create Docker secret. Details: {e}")


def check_if_docker_secret_exists(name):
    url = f"{docker_endpoint}/secrets?filters=%7B%22name%22%3A%5B%22{name}%22%5D%7D"
    try:
        response = requests.get(url)
        response.raise_for_status()
        return len(response.json()) > 0
    except requests.RequestException as e:
        raise SystemExit(f"[ERROR] Could not check whether Docker secret exists. Details: {e}")


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
