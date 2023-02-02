# AWS Secrets Manager to Docker Swarm
Tool to create Docker secrets from AWS Secrets Manager.

## Security considerations
This tool relies on the Docker API, which should not be publicly exposed at all.

The Lambda is deployed in the same VPC, and ideally, you should allow access to the API by security group ID.

The creation of this security group and the attachment to the EC2 is out of the scope of this tool, that should be managed in your code deploying the Docker Swarm cluster. This tool is expecting this security group's ID as an input variable.

When a Lambda is deployed in VPC, it doesn't have access to Internet, hence, it can't access Secrets Manager. There are two approaches to deal with this:
- Create a VPC Endpoint for the Secrets Manager service.
- Create a NAT Gateway and add some routes.

The first is the most secure and simplest, as the traffic never leaves the AWS network. It's not part of this tool either, as it would depend on your infrastructure. This tool is expecting the Secrets Manager endpoint as an input, ideally a VPC Endpoint as recommended.

## Packaging the Lambda
```
$ cd lambda
$ ./package.sh
```

## Deploying
```
$ terraform init
$ terraform apply
```

## Known limitations
By design, Docker does not support update operations. That is, you can't create a secret and then modify its value. How does this translate to this tool?

It works like a charm when you are creating a new secret in Secrets Manager. You create a secret with N keys and then, N secrets will be created in Docker.

However, when you are updating a secret, two things may happen:
- If you are adding a new key, it will work but you will get a warning message notifying you that a secret already exists for every other key in the secret.
- If you are editing an existing key, the content will be never updated in Docker.

So, in summary, it supports creating secrets and adding keys, but it **does not support editing values**.