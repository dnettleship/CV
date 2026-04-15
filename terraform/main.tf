locals {
  bucket_name = "${var.project}-site-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------
# S3 bucket (private — access granted only via CloudFront OAC)
# ------------------------------------------------------------
resource "aws_s3_bucket" "cv" {
  bucket = local.bucket_name

  tags = {
    Project = var.project
  }
}

resource "aws_s3_bucket_public_access_block" "cv" {
  bucket = aws_s3_bucket.cv.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cv" {
  bucket = aws_s3_bucket.cv.id
  policy = data.aws_iam_policy_document.s3_oac.json

  depends_on = [aws_s3_bucket_public_access_block.cv]
}

data "aws_iam_policy_document" "s3_oac" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cv.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cv.arn]
    }
  }
}

# ------------------------------------------------------------
# Upload CV file
# ------------------------------------------------------------
resource "aws_s3_object" "cv" {
  bucket       = aws_s3_bucket.cv.id
  key          = "index.html"
  source       = "${path.module}/../cv.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../cv.html")
}

# ------------------------------------------------------------
# CloudFront Origin Access Control
# ------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "cv" {
  name                              = "${var.project}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ------------------------------------------------------------
# CloudFront distribution
# ------------------------------------------------------------
resource "aws_cloudfront_distribution" "cv" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Europe only

  origin {
    domain_name              = aws_s3_bucket.cv.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.cv.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${local.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimised.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = var.project
  }
}

data "aws_cloudfront_cache_policy" "caching_optimised" {
  name = "Managed-CachingOptimized"
}
