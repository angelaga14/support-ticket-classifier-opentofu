# bootstrap/variables.tf

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Prefijo para los recursos del bootstrap (state bucket, lock table, rol GHA)."
  default     = "demo-cicd-tofu"
}

variable "main_project_name" {
  type        = string
  description = "Prefijo del proyecto principal. El rol GHA solo puede tocar IAM con este prefijo."
  default     = "demo-cicd-tofu"
}

variable "github_repo" {
  type        = string
  description = "Repo de GitHub que puede asumir el rol. Formato: 'owner/repo'."
  # CAMBIA esto antes del primer apply.
  default     = "agusvillarreal/demo-cicd-tofu"
}
