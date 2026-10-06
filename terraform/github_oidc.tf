# GitHub Actions OIDC trust — lets the deploy workflow (.github/workflows/deploy.yml)
# assume an AWS role without any long-lived credentials stored in GitHub.
# The OIDC provider is a single resource per AWS account and already exists
# (set up by another project in this account), so it's referenced as a data
# source rather than managed here.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only workflows running on main in this repo can deploy — not PRs, not
    # other branches, not forks.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:dnettleship/CV:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "TerraformStateObject"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}/cv/terraform.tfstate"]
  }

  statement {
    sid       = "TerraformStateBucketList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}"]
  }

  statement {
    sid       = "SiteBucket"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.cv.arn, "${aws_s3_bucket.cv.arn}/*"]
  }

  statement {
    sid = "CloudFront"
    actions = [
      "cloudfront:Get*",
      "cloudfront:List*",
      "cloudfront:UpdateDistribution",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:CreateInvalidation",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
    ]
    resources = ["*"]
  }

  # Read-only on its own role — enough for Terraform to refresh state on a
  # routine apply. Deliberately excludes Put/Attach/Delete on itself: a CI
  # role that can rewrite its own permissions is a privilege-escalation
  # risk. Changes to this role's own policy go through a human running
  # `terraform apply` locally instead.
  statement {
    sid       = "SelfRoleReadOnly"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies"]
    resources = [aws_iam_role.github_actions.arn]
  }

  statement {
    sid       = "ReadOidcProvider"
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = [data.aws_iam_openid_connect_provider.github.arn]
  }

  # The OIDC provider data source looks the provider up by URL, which lists
  # all providers — IAM doesn't support resource scoping here.
  statement {
    sid       = "ListOidcProviders"
    actions   = ["iam:ListOpenIDConnectProviders"]
    resources = ["*"]
  }

  statement {
    sid       = "StsIdentity"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
