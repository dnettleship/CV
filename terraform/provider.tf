terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-304707804854"
    key    = "cv/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.region
}
