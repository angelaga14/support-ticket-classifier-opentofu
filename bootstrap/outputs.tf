# bootstrap/outputs.tf

output "state_bucket" {
  description = "Pega esto en backend.tf del proyecto principal."
  value       = aws_s3_bucket.state.bucket
}

output "lock_table" {
  description = "Tabla de locks para el state."
  value       = aws_dynamodb_table.locks.name
}

output "gha_role_arn" {
  description = "Pega esto en .github/workflows/tofu.yml como role-to-assume."
  value       = aws_iam_role.gha.arn
}

output "next_steps" {
  description = "Que hacer despues del apply."
  value       = <<-EOT

    Bootstrap completo. Pasos siguientes:

    1. En ../backend.tf cambia:
         bucket = "${aws_s3_bucket.state.bucket}"

    2. En ../.github/workflows/tofu.yml cambia:
         role-to-assume: ${aws_iam_role.gha.arn}

    3. Sube el repo a GitHub con el nombre que usaste en var.github_repo.

    4. cd .. && tofu init && tofu plan
       (correra desde tu laptop la primera vez para validar.
        Despues, GitHub Actions toma el control.)

  EOT
}
