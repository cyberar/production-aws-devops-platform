# GitHub Actions OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "Terraform"
  }
}


# EC2 role: allows instances to use AWS services
resource "aws_iam_role" "ec2" {
  name = "production-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "production-ec2-role"
  }
}


# Allow EC2 to register with Systems Manager
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# Allow EC2 to pull images from the application ECR repository
resource "aws_iam_role_policy" "ec2_ecr_pull" {
  name = "production-ec2-ecr-pull"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}


# EC2 instance profile: attaches the EC2 role to instances
resource "aws_iam_instance_profile" "ec2" {
  name = "production-ec2-instance-profile"
  role = aws_iam_role.ec2.name
}


# GitHub Actions deployment role
resource "aws_iam_role" "github_actions" {
  name = "production-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/${var.github_branch}"
        }
      }
    }]
  })

  tags = {
    Name = "production-github-actions-role"
  }
}


# Allow CI to push images and CD to retrieve image metadata
resource "aws_iam_role_policy" "github_ecr" {
  name = "production-github-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}


# Allow CD to deploy via Systems Manager and switch ALB traffic
# resource "aws_iam_role_policy" "github_deploy" {
#   name = "production-github-deploy"
#   role = aws_iam_role.github_actions.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ssm:SendCommand"
#         ]
#         Resource = [
#           "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
#           var.blue_instance_arn,
#           var.green_instance_arn
#         ]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ssm:GetCommandInvocation",
#           "ssm:ListCommandInvocations"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "elasticloadbalancing:ModifyListener",
#           "elasticloadbalancing:DescribeListeners",
#           "elasticloadbalancing:DescribeTargetHealth"
#         ]
#         Resource = [
#           var.alb_listener_arn,
#           var.blue_target_group_arn,
#           var.green_target_group_arn
#         ]
#       }
#     ]
#   })
# }
