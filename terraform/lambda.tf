# Zip up the lambda function
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

# Lambda - Instance terminated
resource "aws_lambda_function" "tt-as-r53-remove" {
  function_name    = "tt-as-r53-remove"
  handler          = "tt-as-r53-remove.handler"
  runtime          = "python3.6"
  filename         = "${data.archive_file.tt-as-r53-remove.output_path}"
  source_code_hash = "${data.archive_file.tt-as-r53-remove.output_base64sha256}"
  role             = "${aws_iam_role.lambda_exec_role.arn}"
}

# Subscribe lambdas to SNS topics 
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

