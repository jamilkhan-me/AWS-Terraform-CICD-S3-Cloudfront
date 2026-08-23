output "cloudfront_domain_name" {
  description = "Public HTTPS URL of the site."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "site_bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  description = "Needed by the CI pipeline to invalidate the cache after each deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.site.dashboard_name}"
}
