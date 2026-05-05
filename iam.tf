data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_s3_access" {
  statement {
    sid       = "S3WriteTickets"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tickets.arn}/*"]
  }
}

resource "aws_iam_policy" "lambda_s3_access" {
  name   = "${var.project_name}-lambda-s3-access"
  policy = data.aws_iam_policy_document.lambda_s3_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

data "aws_iam_policy_document" "step_function_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "step_function_role" {
  name               = "${var.project_name}-step-function-role"
  assume_role_policy = data.aws_iam_policy_document.step_function_assume.json
}

data "aws_iam_policy_document" "step_function_lambda_invoke" {
  statement {
    sid     = "InvokeTicketLambdas"
    actions = ["lambda:InvokeFunction"]

    resources = [
      aws_lambda_function.validate_ticket.arn,
      aws_lambda_function.classify_ticket.arn,
      aws_lambda_function.route_ticket.arn
    ]
  }
}

resource "aws_iam_policy" "step_function_lambda_invoke" {
  name   = "${var.project_name}-step-function-lambda-invoke"
  policy = data.aws_iam_policy_document.step_function_lambda_invoke.json
}

resource "aws_iam_role_policy_attachment" "step_function_lambda_invoke" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_lambda_invoke.arn
}