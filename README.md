# Terraform Route53 Autoscaling Example

## Summary

This repo demonstrates a Terraform configuration for creating and removing AWS Route 53 entries on a DNS record set when EC2 instances are created or terminated as part of an Autoscaling Group. It does this by sending notifications to SNS via the Autoscaling lifecycle rules and using Lambda functions to update or remove the DNS entries.

## Getting Started

AWS credentials are assumed to be profiles in your `~/.aws/credentials` file. 

Create a vars file with entries specific to your environment.


enter the `terraform` directory and run `terraform init` 
`terraform plan` to see changes to be applied 
`terraform apply` to spin the environment up. 


## Diagram
