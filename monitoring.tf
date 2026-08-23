resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = "alias/aws/sns" # AWS-managed key - encrypts at rest at no extra cost
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudFront publishes these standard metrics to CloudWatch automatically, at no extra cost, but
# ALWAYS in us-east-1 regardless of where the rest of your stack lives — a common gotcha.
resource "aws_cloudwatch_metric_alarm" "high_4xx" {
  alarm_name          = "${var.project_name}-high-4xx-error-rate"
  namespace           = "AWS/CloudFront"
  metric_name         = "4xxErrorRate"
  dimensions          = { DistributionId = aws_cloudfront_distribution.site.id, Region = "Global" }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5 # percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_description   = "More than 5% of requests to the site got a 4xx in the last 5 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_5xx" {
  alarm_name          = "${var.project_name}-high-5xx-error-rate"
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  dimensions          = { DistributionId = aws_cloudfront_distribution.site.id, Region = "Global" }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1 # percent - 5xx should be near-zero for a static site
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_description   = "More than 1% of requests to the site got a 5xx in the last 5 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "site" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Requests"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "4xx / 5xx error rate (%)"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
          ]
          period = 300
          stat   = "Average"
        }
      }
    ]
  })
}
