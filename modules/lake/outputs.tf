output "raw_bucket_id" {
    value = aws_s3_bucket.data_lake_bucket["${var.bucket_name_prefix}-raw"].id
}

output "processed_bucket_id" {
  value = aws_s3_bucket.data_lake_bucket["${var.bucket_name_prefix}-processed"].id
}

output "curated_bucket_id" {
  value = aws_s3_bucket.data_lake_bucket["${var.bucket_name_prefix}-curated"].id
}

output "data_lake_producer_policy" {
  value = aws_iam_policy.data_lake_producer_policy.arn
}

output "data_lake_consumer_policy" {
  value = aws_iam_policy.data_lake_consumer_policy.arn
}
