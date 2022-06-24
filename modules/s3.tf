resource "aws_s3_bucket" "s3Buckets" {
  bucket = var.s3BucketName

  versioning {
    enabled = true
  }
}
