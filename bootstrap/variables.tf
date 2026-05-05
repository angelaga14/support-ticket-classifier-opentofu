variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Bootstrap project name"
  type        = string
  default     = "ticket-classifier-angel-bootstrap"
}

variable "main_project_name" {
  description = "Main project name"
  type        = string
  default     = "demo-cicd-tofu"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the AWS role"
  type        = string
  default     = "angelaga14/support-ticket-classifier-opentofu"
}