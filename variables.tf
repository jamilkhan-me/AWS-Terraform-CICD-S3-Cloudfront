variable "aws_region" {
  description = "AWS region for the S3 bucket and monitoring resources. CloudFront itself is global."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag all resources. Must match bootstrap/variables.tf."
  type        = string
  default     = "static-site-cicd"
}

variable "alert_email" {
  description = "Email address to subscribe to the SNS alarm topic. Leave blank to skip the subscription (the topic and alarms are still created)."
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "PriceClass_100 (NA/EU only) is the cheapest; PriceClass_All covers every edge location."
  type        = string
  default     = "PriceClass_100"
}
