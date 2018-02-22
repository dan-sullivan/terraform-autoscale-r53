# Web tier launch configuraiton
resource "aws_launch_configuration" "tt_as_group" {
  name_prefix   = "lc-tt-as-group-"
  image_id      = "${data.aws_ami.web_ami.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.tt_as_web_instance.id}"]
  associate_public_ip_address = true
  key_name      = "${var.key_name}"
  user_data     = <<EOF
#!/bin/bash
curl http://169.254.169.254/latest/meta-data/public-ipv4 > /var/www/html/index.html
EOF
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
