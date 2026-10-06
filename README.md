# cv

My professional CV, hosted as a static website on AWS.

Live site: https://d3f4keigmofume.cloudfront.net

## Structure

```
cv.html           # The CV webpage
terraform/        # AWS infrastructure
```

## Infrastructure

The site is deployed via CloudFront backed by a private S3 bucket, using Origin Access Control (OAC) to restrict access. Terraform state is stored remotely in S3.

| Resource   | Details                                |
|------------|----------------------------------------|
| S3 bucket  | Private, public access blocked         |
| CloudFront | HTTPS-only, PriceClass_100 (Europe/US) |
| Backend    | `terraform-state-304707804854`         |

## Deploy

```bash
cd terraform
terraform init
terraform apply
```

The `cloudfront_url` output will print the live URL once the deployment completes.