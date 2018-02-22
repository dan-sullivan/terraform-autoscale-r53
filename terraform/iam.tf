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

# Lambda R53 Access, EC2:RO and ASG access
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
