resource "aws_sfn_state_machine" "ticket_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    StartAt = "ValidateTicket",
    States = {
      ValidateTicket = {
        Type     = "Task",
        Resource = aws_lambda_function.validate_ticket.arn,
        Next     = "ClassifyTicket"
      },

      ClassifyTicket = {
        Type     = "Task",
        Resource = aws_lambda_function.classify_ticket.arn,
        Next     = "RouteTicket"
      },

      RouteTicket = {
        Type     = "Task",
        Resource = aws_lambda_function.route_ticket.arn,
        Next     = "CheckSeverity"
      },

      CheckSeverity = {
        Type = "Choice",
        Choices = [
          {
            Variable     = "$.severity",
            StringEquals = "urgent",
            Next         = "SuccessState"
          },
          {
            Variable     = "$.severity",
            StringEquals = "normal",
            Next         = "SuccessState"
          },
          {
            Variable     = "$.severity",
            StringEquals = "low",
            Next         = "SuccessState"
          }
        ],
        Default = "FailState"
      },

      SuccessState = {
        Type = "Succeed"
      },

      FailState = {
        Type  = "Fail",
        Error = "InvalidTicket"
      }
    }
  })
}