# outputs.tf

output "api_url" {
  description = "URL base del API Gateway. Pruebalo con: curl -X POST $api_url/shorten ..."
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "table_name" {
  description = "Nombre de la tabla DynamoDB."
  value       = aws_dynamodb_table.urls.name
}

output "logs_bucket" {
  description = "Bucket S3 donde se loggean visitas."
  value       = aws_s3_bucket.logs.bucket
}
