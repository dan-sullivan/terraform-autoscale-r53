terraform {
  required_version = ">= 0.10.1"
  backend "s3" {
    bucket = "tt-state"
    key    = "prod/terraform.state"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_caller_identity" "current" {}

variable "subnet_id" {
  default = "subnet-13988d6b"
}

variable "dns_zone" {
  default = "tt.internal."
}

variable "dns_prefix" {
  default = "web."
}

data "aws_subnet" "tt_as_group" {
  id = "${var.subnet_id}"
}

data "aws_route53_zone" "tt" {
  name = "${var.dns_zone}"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# IAM Roles
resource "aws_iam_role_policy" "tt_as_sns_access" {
  name = "AutoScalingSNSAccessPolicy"
  role = "${aws_iam_role.tt_as_sns_access.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "sns:Publish"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "tt_as_sns_access" {
  name = "AutoScaling-SNS-Access"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# SNS Topics for AutoScaling LifeCycle Rules
resource "aws_sns_topic" "instance_created" {
  name = "tt-as-group-instance-created"
}

resource "aws_sns_topic" "instance_terminated" {
  name = "tt-as-group-instance-terminated"
}

# Web tier Security Group
resource "aws_security_group" "tt_as_web_instance" {
  name = "tt-web"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web tier launch configuraiton
resource "aws_launch_configuration" "tt_as_group" {
  name_prefix   = "lc-tt-as-group-"
  image_id      = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.tt_as_web_instance.id}"]
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
}

# Web tier auto scaling group
resource "aws_autoscaling_group" "tt_as_group" {
  availability_zones        = ["eu-west-2"]
  name                      = "tt-as-group"
  max_size                  = 5
  min_size                  = 0
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 0
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.tt_as_group.name}"
  vpc_zone_identifier       = ["${data.aws_subnet.tt_as_group.id}"]
  initial_lifecycle_hook {
    name                 = "tt-as-launched"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    notification_target_arn = "${aws_sns_topic.instance_created.arn}"
    role_arn                = "${aws_iam_role.tt_as_sns_access.arn}"
    notification_metadata = <<EOF
{
  "r53_zone": "${data.aws_route53_zone.tt.id}",
  "dns_record": "${var.dns_zone}",
  "dns_prefix": "${var.dns_prefix}"
}
EOF
  }
  initial_lifecycle_hook {
    name                 = "tt-as-terminated"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    notification_target_arn = "${aws_sns_topic.instance_terminated.arn}"
    role_arn                = "${aws_iam_role.tt_as_sns_access.arn}"
    notification_metadata = <<EOF
{
  "r53_zone": "${data.aws_route53_zone.tt.id}",
  "dns_record": "${var.dns_zone}",
  "dns_prefix": "${var.dns_prefix}"
}
EOF
  }

  timeouts {
    delete = "15m"
  }

  lifecycle {
    create_before_destroy = true
  }
}
# Lambda Execution Role
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role_r53_updates"

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
}
# Lambda R53 Access

resource "aws_iam_policy" "tt-r53-rw" {
    name = "tt-r53-rw"
    path = "/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": ["route53:*", "ec2:Describe*", "autoscaling:CompleteLifecycleAction"],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "tt-r53-rw" {
    role       = "${aws_iam_role.lambda_exec_role.name}"
    policy_arn = "${aws_iam_policy.tt-r53-rw.arn}"
}
resource "aws_iam_role_policy_attachment" "basic-exec-role" {
    role       = "${aws_iam_role.lambda_exec_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "tt-as-r53-add" {
  type = "zip"
  output_path = "zips/tt-as-r53-add.zip"
  source {
    filename = "tt-as-r53-add.py"
    content = "${file("../lambda/tt-as-r53-add.py")}"
  }
}

# Lambda - Instance created
resource "aws_lambda_function" "tt-as-r53-add" {
  function_name    = "tt-as-r53-add"
  handler          = "tt-as-r53-add.handler"
  runtime          = "python3.6"
  filename         = "${data.archive_file.tt-as-r53-add.output_path}"
  source_code_hash = "${data.archive_file.tt-as-r53-add.output_base64sha256}"
  role             = "${aws_iam_role.lambda_exec_role.arn}"
}

resource "aws_lambda_permission" "allow_sns" {
  function_name = "${aws_lambda_function.tt-as-r53-add.function_name}"
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.instance_created.arn}"
}

resource "aws_sns_topic_subscription" "tt-as-lambda-create" {
  topic_arn = "${aws_sns_topic.instance_created.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.tt-as-r53-add.arn}"
}

data "archive_file" "tt-as-r53-remove" {
  type = "zip"
  output_path = "zips/tt-as-r53-remove.zip"
  source {
    filename = "tt-as-r53-remove.py"
    content = "${file("../lambda/tt-as-r53-remove.py")}"
  }
}

# Lambda - Instance created
resource "aws_lambda_function" "tt-as-r53-remove" {
  function_name    = "tt-as-r53-remove"
  handler          = "tt-as-r53-remove.handler"
  runtime          = "python3.6"
  filename         = "${data.archive_file.tt-as-r53-remove.output_path}"
  source_code_hash = "${data.archive_file.tt-as-r53-remove.output_base64sha256}"
  role             = "${aws_iam_role.lambda_exec_role.arn}"
}

resource "aws_lambda_permission" "allow_sns-r53-remove" {
  function_name = "${aws_lambda_function.tt-as-r53-remove.function_name}"
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.instance_terminated.arn}"
}

resource "aws_sns_topic_subscription" "tt-as-lambda-terminated" {
  topic_arn = "${aws_sns_topic.instance_terminated.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.tt-as-r53-remove.arn}"
}

