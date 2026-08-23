output "state_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "state_lock_table_name" {
  value = aws_dynamodb_table.lock.name
}

output "github_actions_role_arn" {
  description = "Put this in a GitHub Actions repo secret named AWS_ROLE_ARN."
  value       = aws_iam_role.github_actions.arn
}
