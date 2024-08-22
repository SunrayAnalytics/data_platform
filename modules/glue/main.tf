resource "aws_iam_role" "GlueServiceRole" {
  name = "GdpGlueSvcRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = ["glue.amazonaws.com", "events.amazonaws.com"]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

// Allow Glue to pass it's own role to other services
resource "aws_iam_policy" "GlueServiceRolePassRolePolicy" {
  name = "GlueServiceRolePassRolePolicy"
  description = "Allows Glue to pass roles to other AWS services"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = aws_iam_role.GlueServiceRole.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "GlueServiceRolePassRolePolicyAttachment" {
  name = "GlueServiceRolePassRolePolicyAttachment"
  roles = [aws_iam_role.GlueServiceRole.name]
  policy_arn = aws_iam_policy.GlueServiceRolePassRolePolicy.arn
}

data "aws_iam_policy" "DefaultGlueServicePolicy" {
    arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_policy_attachment" "GlueServiceDefaultPolicyAttachment" {
  name = "GlueServiceRoleAttachment"
  roles = [aws_iam_role.GlueServiceRole.name]
  policy_arn = data.aws_iam_policy.DefaultGlueServicePolicy.arn
}

resource "aws_iam_policy_attachment" "GlueServiceLakeConsumerPolicyAttachment" {
  name = "GlueServiceLakeConsumerPolicyAttachment"
  roles = [aws_iam_role.GlueServiceRole.name]
  policy_arn = var.data_lake_consumer_policy
}

resource "aws_iam_policy_attachment" "GlueServiceLakeProducerPolicyAttachment" {
  name = "GlueServiceLakeProducerPolicyAttachment"
  roles = [aws_iam_role.GlueServiceRole.name]
  policy_arn = var.data_lake_producer_policy
}
