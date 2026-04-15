output "cloudfront_url" {
  description = "Public URL of the CV site"
  value       = "https://${aws_cloudfront_distribution.cv.domain_name}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the CV"
  value       = aws_s3_bucket.cv.id
}
