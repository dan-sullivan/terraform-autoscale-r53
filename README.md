# Terraform Route53 Autoscaling Example

## Summary

This repo demonstrates a Terraform configuration for creating and removing AWS Route 53 entries on a DNS record set when EC2 instances are created or terminated as part of an Autoscaling Group. It does this by sending notifications to SNS via the Autoscaling lifecycle rules and using Lambda functions to add or remove the DNS entries and health checks.

## The Flow

###  Scale out
1. An autoscaling scale-out trigger event occurs e.g. Cloudwatch metrics threshbold breach
2. The autoscaling group starts a new instance based on the launch configuration
3. A lifecycle hook for LAUNCHING is created and sent to SNS
4. A Lambda function subscribed to the SNS topic creates a new DNS entry and an associated health check in Route 53
5. A lifecycle CONTINUE is sent back to the Autoscaling group

###  Scale in
1. An autoscaling scale-in trigger event occurs e.g. Cloudwatch metrics threshbold back within constraints
2. The autoscaling group terminates an instance
3. A lifecycle hook for TERMINATING is created and sent to SNS
4. A Lambda function subscribed to the SNS topic removes the DNS entry and associated health check in Route 53
5. A lifecycle CONTINUE is sent back to the Autoscaling group


## High Level Diagram
![Diagram](Autoscaling_Lambda_R53.png)

## Getting Started

AWS credentials are assumed to be profiles in your `~/.aws/credentials` file. You can specify the profile in the tfvars file or leave blank for `default`

Amend backend state config in `terraform/main.tf` to point to your statefiles bucket or another backend.

Enter the terraform directory and create a  `terraform.tfvars` file with the following:

```
subnet_id   = "subnet-12345678"
dns_zone    = "mysite.com."
dns_prefix  = "www"
key_name    = "tt-dsul"
region      = "eu-west-2"
ami_name    = "my-ami*"
profile     = "my-optional-profile"
```

The dns zone will used to lookup your zone id in Route 53. Ensure it has the . at the end.

The dns_prefix will be used to form your fqdn and in the set name for the weighted dns records.

The ami_name is used as a search string for your ami in your account. Look in packer for a simple packer script to build an ubuntu apache ami.


### Build

Enter the `terraform` directory and run `terraform init`  
`terraform plan` to see changes to be applied  
`terraform apply` to spin the environment up.  


