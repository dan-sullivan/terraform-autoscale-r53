variable "subnet_id" {}
variable "dns_zone" {}
variable "dns_prefix" {}
variable "key_name" {}
variable "ami_name" {}
variable "region" {}
variable "profile" {
  default = "default"
}

terraform {
  required_version = ">= 0.10.1"
  backend "s3" {
    bucket = "tt-state"
    key    = "prod/terraform.state"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "${var.region}"
  profile = "${var.profile}"
}

data "aws_caller_identity" "current" {}

data "aws_subnet" "tt_as_group" {
  id = "${var.subnet_id}"
}

data "aws_route53_zone" "tt" {
  name = "${var.dns_zone}"
}

data "aws_ami" "web_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami_name}"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["self"] # Our account
}
