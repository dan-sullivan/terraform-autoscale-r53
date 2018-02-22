# SNS Topics for AutoScaling LifeCycle Rules
resource "aws_sns_topic" "instance_created" {
  name = "tt-as-group-instance-created"
}

resource "aws_sns_topic" "instance_terminated" {
  name = "tt-as-group-instance-terminated"
}

