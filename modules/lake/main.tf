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
  bucket   = each.value

  tags = {
    Name        = "${var.environment_name} Data Lake"
    Environment = "Prod"
  }
}


resource "aws_lakeformation_resource" "resource" {
  for_each = aws_s3_bucket.data_lake_bucket

  arn                   = each.value.arn
  hybrid_access_enabled = true
}

resource "aws_lakeformation_data_lake_settings" "data_lake_settings" {
  admins = concat(var.lake_administrators, ["arn:aws:iam::184065244952:user/hapeha"])

  create_database_default_permissions {
    permissions = ["ALL"]
    principal   = "IAM_ALLOWED_PRINCIPALS"
  }

  create_table_default_permissions {
    permissions = ["ALL"]
    principal   = "IAM_ALLOWED_PRINCIPALS"
  }
}

resource "aws_lakeformation_permissions" "data_location_access" {
  for_each    = aws_s3_bucket.data_lake_bucket
  principal   = var.lake_administrators[0]
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = each.value.arn
  }
  permissions_with_grant_option = ["DATA_LOCATION_ACCESS"]
}

#locals {
#  buckets = [
#    for key, bucket in aws_s3_bucket.data_lake_bucket : bucket
#  ]
#
#}

// TODO Should do a set product of this
resource "aws_lakeformation_permissions" "data_location_access2" {
  for_each    = aws_s3_bucket.data_lake_bucket
  principal   = var.lake_administrators[2]
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = each.value.arn
  }
  permissions_with_grant_option = ["DATA_LOCATION_ACCESS"]
}

resource "aws_s3_bucket_acl" "data_lake_bucket_acl" {
  for_each   = aws_s3_bucket.data_lake_bucket
  bucket     = each.value.id
  acl        = "private"
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
  bucket   = each.value.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "raw_bucket_policy" {
  bucket = aws_s3_bucket.data_lake_bucket["${var.bucket_name_prefix}-raw"].id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Sid" : "AllowAppFlowDestinationActions",
        "Principal" : {
          "Service" : "appflow.amazonaws.com"
        },
        "Action" : [
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "s3:ListBucketMultipartUploads",
          "s3:GetBucketAcl",
          "s3:PutObjectAcl"
        ],
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.data_lake_bucket["${var.bucket_name_prefix}-raw"].id}",
          "arn:aws:s3:::${aws_s3_bucket.data_lake_bucket["${var.bucket_name_prefix}-raw"].id}/*",
        ]
      }

    ]
  })

}

resource "aws_iam_role" "appflow_role" {
  name = "GdpAppflowSvcRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "appflow.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_policy" "appflow_policy" {
  name        = "appflow_policy"
  description = "Policy for Appflow to write to the raw bucket"
  policy      = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AppflowGluePolicy",
          "Effect" : "Allow",
          "Action" : [
            "glue:BatchCreatePartition",
            "glue:CreatePartitionIndex",
            "glue:DeleteDatabase",
            "glue:GetTableVersions",
            "glue:GetPartitions",
            "glue:BatchDeletePartition",
            "glue:DeleteTableVersion",
            "glue:UpdateTable",
            "glue:DeleteTable",
            "glue:DeletePartitionIndex",
            "glue:GetTableVersion",
            "glue:CreatePartition",
            "glue:UntagResource",
            "glue:UpdatePartition",
            "glue:TagResource",
            "glue:UpdateDatabase",
            "glue:CreateTable",
            "glue:BatchUpdatePartition",
            "glue:GetTables",
            "glue:BatchGetPartition",
            "glue:GetDatabases",
            "glue:GetPartitionIndexes",
            "glue:GetTable",
            "glue:GetDatabase",
            "glue:GetPartition",
            "glue:CreateDatabase",
            "glue:BatchDeleteTableVersion",
            "glue:BatchDeleteTable",
            "glue:DeletePartition"
          ],
          "Resource" : "*"
        }
      ]
    })
}

resource "aws_iam_role_policy_attachment" "appflow_policy_attachment" {
  role       = aws_iam_role.appflow_role.name
  policy_arn = aws_iam_policy.appflow_policy.arn
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
  policy = jsonencode(
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
        "Resource" : [for bucket_name, bucket in aws_s3_bucket.data_lake_bucket : "arn:aws:s3:::${bucket.id}/*"]
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
        "Resource" : [for bucket_name, bucket in aws_s3_bucket.data_lake_bucket : "arn:aws:s3:::${bucket.id}/*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:List*"
        ],
        "Resource" : [for bucket_name, bucket in aws_s3_bucket.data_lake_bucket : "arn:aws:s3:::${bucket.id}"]
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
