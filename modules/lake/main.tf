data "aws_caller_identity" "current" {}

locals {
    bucket_names = [
      "${var.bucket_name_prefix}-raw",
      "${var.bucket_name_prefix}-processed",
      "${var.bucket_name_prefix}-curated"
    ]
}

resource "aws_s3_bucket" "data_lake_bucket" {
  for_each = toset(local.bucket_names)
  bucket = each.value

  tags = {
    Name        = "${var.environment_name} Data Lake"
    Environment = "Prod"
  }
}


resource "aws_lakeformation_resource" "resource" {
  for_each = aws_s3_bucket.data_lake_bucket

  arn = each.value.arn
#  hybrid_access_enabled = true
}

resource "aws_lakeformation_data_lake_settings" "data_lake_settings" {
  admins = ["arn:aws:iam::184065244952:user/sunray_deploy"] # TODO, parameterize this
}

resource "aws_s3_bucket_acl" "data_lake_bucket_acl" {
  for_each = aws_s3_bucket.data_lake_bucket
  bucket = each.value.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.data_lake_bucket]
}

#resource "aws_s3_bucket_lifecycle_configuration" "data_lake_bucket_lifecycle_configuration" {
#  bucket = aws_s3_bucket.data_lake_bucket.id
#  rule {
#    id = "staging-zone"
#
#    status = "Enabled"
#
#    filter {
#      prefix = "staging/"
#    }
#
#    expiration {
#      days = 30
#    }
#  }
#}
#
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_bucket_sse_config" {
  for_each = aws_s3_bucket.data_lake_bucket

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data_lake_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
#
resource "aws_s3_bucket_ownership_controls" "data_lake_bucket" {
  for_each = aws_s3_bucket.data_lake_bucket
  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
#
#resource "aws_s3_bucket_policy" "rds_writing" {
#  bucket = aws_s3_bucket.data_lake_bucket.id
#  policy = jsonencode({
#    "Version" : "2012-10-17",
#    "Statement" : [
#      {
#        "Principal" : {
#          "AWS" : "*"
#        },
#        "Action" : [
#          "s3:*"
#        ],
#        "Resource" : [
#          "arn:aws:s3:::${aws_s3_bucket.data_lake_bucket.id}/*",
#          "arn:aws:s3:::${aws_s3_bucket.data_lake_bucket.id}"
#        ],
#        "Effect" : "Deny",
#        "Condition" : {
#          "Bool" : {
#            "aws:SecureTransport" : "false"
#          }
#        }
#      }
#    ]
#  })
#}
#

resource "aws_s3_bucket_public_access_block" "data_lake_bucket" {
  for_each = aws_s3_bucket.data_lake_bucket

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_kms_key" "data_lake_key" {
  description = "This key is used to encrypt data lake objects"
  #   deletion_window_in_days = 10
  policy      = jsonencode(
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "allowallfrommyaccount",
        "Effect" : "Allow",
        "Principal" : { "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        "Action" : ["kms:*"],
        "Resource" : "*",
      }
    ]
  }
  )
}
resource "aws_iam_policy" "data_lake_producer_policy" {
  name        = "data_lake_producer_policy"
  path        = "/"
  description = "Gives permission to produce files in the data lake"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:Put*",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" : [for bucket_name, bucket in aws_s3_bucket.data_lake_bucket: "arn:aws:s3:::${bucket.id}/*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:Decrypt"
        ],
        "Resource" : aws_kms_key.data_lake_key.arn
      }
    ]
  })
}

resource "aws_iam_policy" "data_lake_consumer_policy" {
  name        = "data_lake_consumer_policy"
  path        = "/"
  description = "Gives read access to the data lake"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*"
        ],
        "Resource" : [for bucket_name, bucket in aws_s3_bucket.data_lake_bucket: "arn:aws:s3:::${bucket.id}/*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:List*"
        ],
        "Resource" : [for bucket_name, bucket in aws_s3_bucket.data_lake_bucket: "arn:aws:s3:::${bucket.id}"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ],
        "Resource" : aws_kms_key.data_lake_key.arn
      }
    ]
  })
}
