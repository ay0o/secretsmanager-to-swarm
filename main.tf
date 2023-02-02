terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {}

resource "aws_iam_policy" "secretsmanager-read" {
  name        = "SecretManagerReadAccess"
  description = "Access to get Secrets from Secrets Manager"

  policy = <<EOF
{
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecrets"
        ],
        "Effect" : "Allow",
        "Resource" : "${var.secrets_path}"
      }
    ]
}
EOF
}

resource "aws_iam_role" "lambda_role" {
  name = "secretsmanager-to-swarm"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  managed_policy_arns = [
    aws_iam_policy.secretsmanager-read.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
}

resource "aws_lambda_function" "lambda_function" {
  filename      = "${path.module}/lambda/lambda.zip"
  function_name = "secretsmanager-to-swarm"
  handler       = "app.handler"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"

  environment {
    variables = {
      docker_endpoint             = var.docker_endpoint
      secretsmanager_endpoint = var.secrets_manager_endpoint
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

resource "aws_cloudwatch_event_rule" "secretsmanager" {
  name          = "secretsmanager"
  description   = "Trigger when a secret has been created"
  event_pattern = <<EOF
{
  "source": ["aws.secretsmanager"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["secretsmanager.amazonaws.com"],
    "eventName": ["CreateSecret", "PutSecretValue"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.secretsmanager.name
  arn  = aws_lambda_function.lambda_function.arn
}

resource "aws_lambda_permission" "allow-event-bridge" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.secretsmanager.arn
  statement_id  = "AllowExecutionFromEventBridge"
}