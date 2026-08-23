variable "aws_region" {
  description = "AWS region for the state bucket, lock table, and CloudWatch alarms."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Must match the project_name used in ../variables.tf — used to scope IAM permissions."
  type        = string
  default     = "static-site-cicd"
}

variable "github_repository" {
  description = "GitHub repo allowed to assume the CI role, as \"owner/repo\" (e.g. \"jkhan/aws-portfolio\")."
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the CI role for terraform apply. Other branches/PRs can still assume it for plan-only if you widen the sub claim condition below."
  type        = string
  default     = "main"
}
