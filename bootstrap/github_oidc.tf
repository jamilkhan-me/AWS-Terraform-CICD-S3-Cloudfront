# Fetches GitHub's current OIDC signing certificate thumbprint so AWS can validate tokens from
# token.actions.githubusercontent.com. AWS also accepts this provider without a thumbprint at all
# now (it validates against its own trust store), but pinning one is still the documented pattern.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restricts WHO can assume this role to: this exact repo, on this exact branch.
    # A pull_request event from a fork, or a push to any other branch, is denied.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Scoped to what the main project actually creates: the state bucket/lock table (for backend
# init/plan/apply), buckets prefixed with this project's name, and CloudFront/CloudWatch/SNS —
# the latter three don't support fine-grained resource ARNs for most of the actions Terraform
# needs (plan/read/create/delete), which is a real AWS IAM limitation worth knowing about, not
# an oversight here.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "TerraformStateBackend"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
  }

  statement {
    sid       = "TerraformStateLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.lock.arn]
  }

  statement {
    sid = "SiteBucketManage"
    actions = [
      "s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket",
      "s3:PutBucketPolicy", "s3:GetBucketPolicy", "s3:DeleteBucketPolicy",
      "s3:PutBucketVersioning", "s3:GetBucketVersioning",
      "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock",
      "s3:PutEncryptionConfiguration", "s3:GetEncryptionConfiguration",
      "s3:PutBucketTagging", "s3:GetBucketTagging",
      "s3:PutBucketOwnershipControls", "s3:GetBucketOwnershipControls",
      "s3:GetBucketAcl", "s3:GetBucketLocation", "s3:GetBucketLogging", "s3:GetLifecycleConfiguration",
    ]
    resources = ["arn:aws:s3:::${var.project_name}-*"]
  }

  statement {
    sid       = "SiteBucketObjectSync"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.project_name}-*/*"]
  }

  statement {
    # Actions AWS allows scoping to a specific distribution ARN once it exists.
    sid = "CloudFrontManageExistingDistribution"
    actions = [
      "cloudfront:GetDistribution", "cloudfront:UpdateDistribution", "cloudfront:DeleteDistribution",
      "cloudfront:TagResource", "cloudfront:UntagResource", "cloudfront:ListTagsForResource",
      "cloudfront:CreateInvalidation", "cloudfront:GetInvalidation", "cloudfront:ListInvalidations",
    ]
    resources = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
  }

  statement {
    # AWS does not support resource-level restriction on these specific actions (documented IAM
    # limitation, not a shortcut taken here) - CreateDistribution has no ID to scope to yet,
    # and OAC/list actions are account-level by design.
    sid = "CloudFrontAccountLevelActions"
    actions = [
      "cloudfront:CreateDistribution", "cloudfront:ListDistributions",
      "cloudfront:CreateOriginAccessControl", "cloudfront:GetOriginAccessControl", "cloudfront:ListOriginAccessControls",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchAlarmsAndDashboard"
    actions = [
      "cloudwatch:PutMetricAlarm", "cloudwatch:DescribeAlarms", "cloudwatch:DeleteAlarms", "cloudwatch:TagResource",
    ]
    resources = ["arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-*"]
  }

  statement {
    sid = "CloudWatchDashboard"
    actions = [
      "cloudwatch:PutDashboard", "cloudwatch:GetDashboard", "cloudwatch:DeleteDashboards", "cloudwatch:ListDashboards",
    ]
    resources = ["arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${var.project_name}-*"]
  }

  statement {
    sid = "SnsTopic"
    actions = [
      "sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes",
      "sns:Subscribe", "sns:Unsubscribe", "sns:ListSubscriptionsByTopic", "sns:TagResource",
    ]
    resources = ["arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.project_name}-github-actions-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
