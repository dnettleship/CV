variable "region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "cv"
}
