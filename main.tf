provider "aws" {
  region = var.aws_region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tickets" {
  bucket        = "${var.project_name}-tickets-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "tickets" {
  bucket                  = aws_s3_bucket.tickets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "archive_file" "validate_ticket_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/validate_ticket"
  output_path = "${path.module}/.build/validate_ticket.zip"
}

data "archive_file" "classify_ticket_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/classify_ticket"
  output_path = "${path.module}/.build/classify_ticket.zip"
}

data "archive_file" "route_ticket_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/route_ticket"
  output_path = "${path.module}/.build/route_ticket.zip"
}

resource "aws_lambda_function" "validate_ticket" {
  function_name    = "${var.project_name}-validate-ticket"
  filename         = data.archive_file.validate_ticket_zip.output_path
  source_code_hash = data.archive_file.validate_ticket_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
}

resource "aws_lambda_function" "classify_ticket" {
  function_name    = "${var.project_name}-classify-ticket"
  filename         = data.archive_file.classify_ticket_zip.output_path
  source_code_hash = data.archive_file.classify_ticket_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
}

resource "aws_lambda_function" "route_ticket" {
  function_name    = "${var.project_name}-route-ticket"
  filename         = data.archive_file.route_ticket_zip.output_path
  source_code_hash = data.archive_file.route_ticket_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.tickets.bucket
    }
  }
}

resource "aws_cloudwatch_log_group" "validate_ticket_logs" {
  name              = "/aws/lambda/${aws_lambda_function.validate_ticket.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "classify_ticket_logs" {
  name              = "/aws/lambda/${aws_lambda_function.classify_ticket.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "route_ticket_logs" {
  name              = "/aws/lambda/${aws_lambda_function.route_ticket.function_name}"
  retention_in_days = 7
}