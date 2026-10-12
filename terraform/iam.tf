resource "aws_iam_role_policy" "github_deploy" {
  name = "production-github-deploy"
  role = module.iam.github_actions_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DeployToBlueGreenInstances"
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
          module.ec2.blue_instance_arn,
          module.ec2.green_instance_arn
        ]
      },
      {
        Sid    = "ReadDeploymentStatus"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      },
      {
        Sid    = "SwitchBlueGreenTraffic"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyListener"
        ]
        Resource = [module.alb.listener_arn]
      },
      {
        Sid    = "ReadLoadBalancerHealth"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      }
    ]
  })
}
