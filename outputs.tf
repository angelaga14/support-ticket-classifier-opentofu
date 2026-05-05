output "ticket_bucket" {
  description = "S3 bucket where routed tickets are stored"
  value       = aws_s3_bucket.tickets.bucket
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.ticket_pipeline.arn
}

output "validate_lambda_name" {
  value = aws_lambda_function.validate_ticket.function_name
}

output "classify_lambda_name" {
  value = aws_lambda_function.classify_ticket.function_name
}

output "route_lambda_name" {
  value = aws_lambda_function.route_ticket.function_name
}