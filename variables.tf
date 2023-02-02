variable "docker_endpoint" {
  description = "Docker API endpoint"
  type        = string
}

variable "secrets_manager_endpoint" {
  description = "Endpoint to access AWS Secrets Manager within the VPC"
  type        = string
}

variable "secrets_path" {
  description = "Use this to limit the access of the Lambda to Secrets Manager, otherwise it has access to all secrets"
  default     = "*"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where Docker Swarm is deployed"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of a Security Group granting access to the Docker API"
  type        = string
}
