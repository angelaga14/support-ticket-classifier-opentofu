# backend.tf
# Configuracion del backend remoto. El bucket y la tabla DynamoDB
# fueron creados por el bootstrap (carpeta bootstrap/) UNA SOLA VEZ.
#
# IMPORTANTE: el alumno debe cambiar el valor de "bucket" por el que
# le devolvio el bootstrap. La tabla y region son fijas.

terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    # CAMBIA esto por tu bucket. Lo imprime el output del bootstrap.
    bucket = "demo-cicd-tofu-state-fe1704c4"

    key            = "support-ticket-classifier/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "demo-cicd-tofu-locks"
    encrypt        = true
  }
}
