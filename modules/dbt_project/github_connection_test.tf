# TODO: Maybe we can only have one openid connect provider per account?
resource "aws_iam_openid_connect_provider" "default" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "token.actions.githubusercontent.com:aud"
    }
    // https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
    // https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html
    condition {
      test     = "StringEquals"
      values   = ["repo:${var.dbt_project.github.org}/${var.dbt_project.github.repo}:environment:prod"]
      variable = "token.actions.githubusercontent.com:sub"
    }
  }
}

# TODO This needs shortening
resource "aws_iam_role" "github_oidc_role" {
  name               = "gb-${var.tenant_id}-${var.dbt_project.github.org}-${var.dbt_project.github.repo}-oidc"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
  tags = {
    Tenant     = var.tenant_id
    GithubOrg  = var.dbt_project.github.org
    GithubRepo = var.dbt_project.github.repo
  }
}


resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" // TODO: Set up a proper policy for what we want to do
}
