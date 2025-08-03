data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
  }
}

module "s3_bucket" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.2.0"

  bucket_prefix = "igorovo-"

  attach_policy = true
  policy        = data.aws_iam_policy_document.s3_bucket_policy.json

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "index_html_no_cache" {
  name = "NoCacheIndexHtml"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "no-store, no-cache, must-revalidate"
      override = true
    }
    items {
      header   = "Pragma"
      value    = "no-cache"
      override = true
    }
    items {
      header   = "Expires"
      value    = "0"
      override = true
    }
  }
}

module "cloudfront" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-cloudfront.git?ref=v5.0.0"

  http_version = "http2and3"

  create_origin_access_control = true

  origin_access_control = {
    s3_oac = {
      description      = "OAC for private S3 access"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3 = {
      domain_name           = module.s3_bucket.s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_oac"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_name    = "Managed-CachingOptimized" # Optimized caching for static assets
    use_forwarded_values = false                      # Have to be disabled for cache policy
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/index.html"
      target_origin_id       = "s3"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true

      response_headers_policy_id = aws_cloudfront_response_headers_policy.index_html_no_cache.id

      cache_policy_name    = "Managed-CachingDisabled"
      use_forwarded_values = false
    }
  ]

  viewer_certificate = {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1" # TLSv1.2_2021 is not supported with default cert
  }

  custom_error_response = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    }
  ]
}
