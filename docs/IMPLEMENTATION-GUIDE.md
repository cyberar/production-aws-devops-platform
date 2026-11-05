# End-to-End Implementation Guide

This guide describes the implementation sequence for the platform. It is written as a reproducible workflow, but exact Terraform filenames, variable names, and GitHub workflow paths must match the current repository. Where the repository's exact name is not known from the project notes, this guide describes the purpose rather than inventing a filename.

## 1. Prepare the workstation

Install and verify:

- Git
- Terraform (the project configuration has used Terraform `>= 1.5`)
- AWS CLI v2
- Docker Engine
- A GitHub account and repository

Verify the tools:

```bash
git --version
terraform version
aws --version
docker --version
```

Configure AWS CLI using an IAM identity intended for infrastructure provisioning. Do not use root-account access keys.

```bash
aws configure
aws sts get-caller-identity
aws configure get region
```

The project has been deployed in `us-east-1`. Confirm the active region before running AWS or Terraform commands.

## 2. Obtain the source

```bash
git clone https://github.com/cyberar/production-aws-devops-platform.git
cd production-aws-devops-platform
```

Inspect the repository before running commands:

```bash
find . -maxdepth 3 -type f \
  -not -path './.git/*' \
  -not -path './.terraform/*' \
  | sort
```

Do not commit `.terraform/`, Terraform state files, credentials, private keys, or environment files containing secrets.

## 3. Understand the Terraform configuration

Move into the Terraform directory:

```bash
cd terraform
```

Review the configuration files and identify:
- Terraform and provider version constraints.
- AWS region and provider configuration.
- VPC, subnet, route, and internet-gateway resources.
- ALB, listener, and target groups.
- EC2 instances, AMIs, instance profiles, and IAM roles.
- Security groups.
- ECR repository.
- Outputs and input variables.

Initialize and validate:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
```

Review the plan:

```bash
terraform plan
```

Apply only after checking the resources, region, CIDRs, instance types, and expected cost:

```bash
terraform apply
```

Record the outputs needed by CI/CD, such as instance IDs, ALB ARN, target-group ARNs, ECR repository name, and IAM role ARN. Use Terraform outputs where available instead of copying values from the console.

## 4. Build and test the container locally

The application image uses Nginx and listens inside the container on port 8080. The EC2 deployment maps host port 80 to container port 8080.

From the application build context used by the CI workflow, build a local image. Adapt the path to the Dockerfile location:

```bash
docker build -t production-devops-app:local ./app
```

Run a local test:

```bash
docker run --rm -d \
  --name production-devops-local \
  -p 8080:8080 \
  production-devops-app:local
```

Test the response:

```bash
curl -i http://localhost:8080/
```

Stop the test container:

```bash
docker stop production-devops-local
```

The project Dockerfile configures Nginx to listen on 8080, sets a writable PID path under `/tmp`, and runs Nginx as the non-root `nginx` user. Keep the Dockerfile, container port, EC2 host mapping, and ALB target port consistent.

## 5. Configure GitHub-to-AWS OIDC

Create or verify the GitHub OIDC identity provider and IAM role used by the workflow. The role trust policy should restrict access to the intended GitHub organization/user, repository, branch, and/or GitHub Environment subject. The permissions policy should grant only the AWS actions required by the pipeline.

The project has used this deployment role ARN:

```text
arn:aws:iam::292659698191:role/production-github-actions-role
```

Treat this as an environment-specific example. If deploying into another account, use that account's role ARN. Do not place long-lived AWS access keys in GitHub secrets when OIDC is configured.

## 6. Configure GitHub variables and environments

The CD workflow has used the GitHub Environment named `Staging`. A job-level `environment:` declaration determines which environment's variables and secrets are available. If the workflow says `environment: Staging`, putting values only in repository variables or a different environment may not provide the values the job expects.

Configure the variables referenced by the actual workflow. The project has used these names:

| Variable | Purpose |
|---|---|
| `AWS_REGION` | AWS deployment region (`us-east-1` in this deployment) |
| `AWS_ACCOUNT_ID` | AWS account ID |
| `ECR_REPOSITORY` | ECR repository name (`production-devops-app`) |
| `AWS_ROLE_ARN` | GitHub OIDC deployment role ARN |
| `ALB_ARN` | Application Load Balancer ARN |
| `BLUE_TG_ARN` | Blue target-group ARN |
| `GREEN_TG_ARN` | Green target-group ARN |
| Blue/green instance ID variables | EC2 instance identifiers used by the workflow |

Use the exact variable names in the current workflow YAML. Do not create a similarly named variable if the workflow expects a different spelling. Keep secrets out of variable values and source code.

## 7. Run CI

The CI workflow is configured to build the Docker image, scan it with Trivy, and publish an approved image to ECR on the configured main-branch push path.

Make a small application change, commit, and push:

```bash
git status
git add .
git commit -m "Document or update application"
git push origin main
```

In GitHub Actions, inspect the CI run:
- Confirm the image build succeeds.
- Review the Trivy report.
- Confirm the workflow fails when its configured scan policy is violated.
- Confirm the publish job runs only on the intended successful push path.
- Confirm the commit-SHA image tag appears in ECR.

Do not assume a successful PR scan also publishes an image; the project pipeline distinguishes pull-request validation from the main-branch image-publishing path.

## 8. Run Bootstrap

The Continuous Deployment (CD) workflow is triggered automatically after a successful completion of the Continuous Integration (CI) workflow. It can also be triggered manually by providing a full commit SHA.

Before approving or executing the CD workflow, ensure that the bootstrap workflow (bootstrap.yaml) has been run successfully.

The bootstrap workflow prepares the required deployment environment by installing and configuring the necessary tools, including:
- Docker - to run the containerized application.
- AWS CLI - to interact with AWS services.
- Any other dependencies required by the deployment process.

## 9. Run CD

The CD workflow can be triggered by a successful CI workflow completion and/or manual dispatch with a full commit SHA, depending on the current workflow configuration.

Before triggering:
- Confirm the requested image tag exists in ECR.
- Confirm the GitHub Environment selected by the job contains the required variables.
- Confirm both target groups are associated with the ALB listener.
- Confirm the active target group is healthy.
- Confirm the inactive instance is registered and reachable by SSM.

Follow the workflow logs. The expected order is identify active/inactive, deploy to inactive, wait for ALB health, then promote traffic. Do not manually change listener weights while a deployment workflow is in progress.

## 10. Verify AWS resources

List the ALB:

```bash
aws elbv2 describe-load-balancers \
  --names production-devops-alb \
  --region us-east-1 \
  --output table
```

Inspect target groups:

```bash
aws elbv2 describe-target-groups \
  --names production-blue-tg production-green-tg \
  --region us-east-1 \
  --query 'TargetGroups[*].[TargetGroupName,TargetGroupArn,LoadBalancerArns[0]]' \
  --output table
```

Check each target group's health:

```bash
for TG in production-blue-tg production-green-tg; do
  echo "===== $TG ====="
  TG_ARN=$(aws elbv2 describe-target-groups \
    --names "$TG" \
    --region us-east-1 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

  aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
done
```

Inspect listener weights:

```bash
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names production-devops-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --region us-east-1 \
  --query 'Listeners[*].DefaultActions' \
  --output json
```

A normal steady state has one target group at weight 100 and the other at weight 0. Both should be healthy when both environments are ready for failover.

## 11. Configure and verify monitoring

The implemented dashboard is named `production-devops-platform`. The SNS topic is named `production-devops-alerts`. The project has six alarms for target health, EC2 CPU, and ALB/application 5xx counts.

List dashboards:

```bash
aws cloudwatch list-dashboards \
  --region us-east-1 \
  --query "DashboardEntries[?DashboardName=='production-devops-platform']" \
  --output table
```

List alarms:

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix production- \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

Verify the SNS subscription is confirmed:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn YOUR_SNS_TOPIC_ARN \
  --region us-east-1 \
  --output table
```

The subscription status should be `Confirmed`. The email notification test should be performed only after the topic subscription is confirmed.

## 12. Clean up

This project provisions billable AWS resources. If the environment is no longer required, review all dependencies and the Terraform destroy plan:

```bash
terraform plan -destroy
terraform destroy
```

Run Terraform commands from the Terraform directory. Review resources created outside Terraform separately, including CloudWatch dashboards and alarms and SNS topics/subscriptions.
