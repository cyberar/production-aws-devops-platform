# CI/CD Guide

## 1. Overview

The project separates continuous integration from continuous deployment.

- **CI** builds the container image, scans it with Trivy, and publishes an approved image to ECR on the configured main-branch push path.
- **CD** obtains temporary AWS credentials through GitHub OIDC, identifies the inactive environment, deploys the selected image through SSM, validates ALB target health, and promotes traffic.

The current workflow names and paths in the repository are authoritative. The CI workflow name used by the CD `workflow_run` trigger has been `CI - Build and Scan Application`.

## 2. Continuous integration

The CI workflow is configured to run for pull requests and pushes to `main`.

Its logical stages are:

1. Check out source.
2. Build a Docker image from the application build context (`./app` in the documented workflow).
3. Tag the image with the Git commit SHA.
4. Scan the image with Trivy.
5. Fail the CI job when the configured severity policy is violated.
6. For the successful main-branch push path, save the image as a workflow artifact.
7. Publish the image to Amazon ECR with the commit SHA tag.

A pull-request scan and a main-branch image publication are different paths. Verify the workflow conditions before expecting an image to appear in ECR.

## 3. Why use a commit SHA tag?

A commit SHA identifies the source revision used to build the image. It makes releases traceable and allows CD to deploy a specific image version. Avoid using only a mutable `latest` tag for release selection.

The manual CD dispatch path expects a full 40-character image SHA, according to the workflow design described for this project.

## 4. Trivy image scanning

Trivy scans the built image for vulnerabilities. The workflow's configured severity and exit-code policy determines whether findings fail the pipeline. Read the current YAML to confirm exact severity values and whether unfixed vulnerabilities are included.

A scan passing means no findings matched that configured failure policy; it does not prove the image is vulnerability-free.

## 5. Publishing to Amazon ECR

The publish job authenticates to ECR, tags the image with the account/region/repository path and commit SHA, then pushes it. The repository name used by this project is `production-devops-app`.

Useful inspection command:

```bash
aws ecr describe-images \
  --repository-name production-devops-app \
  --region us-east-1 \
  --query 'imageDetails[*].[imageTags,imageDigest,imagePushedAt]' \
  --output table
```

## 6. GitHub OIDC authentication

GitHub Actions requests an OIDC token and exchanges it with AWS STS to assume the configured IAM role. This avoids storing long-lived AWS access keys in GitHub.

The workflow has used:

```text
arn:aws:iam::292659698191:role/production-github-actions-role
```

This ARN belongs to the documented AWS account. Replace it when reproducing the project in another account.

The IAM trust policy should restrict which GitHub repository, branch, and/or environment can assume the role. The role permissions policy should be limited to the actions required by CI/CD. Confirm the actual policy documents rather than assuming the role is least-privilege.

## 7. GitHub Environments and variables

A job-level `environment:` declaration controls which GitHub Environment's variables and secrets are exposed to that job. This project has used `environment: Staging`. If the workflow selects `Staging`, values stored only under another environment will not automatically be available.

The workflow has used variables for:
- AWS region and account ID.
- ECR repository name.
- OIDC role ARN.
- ALB ARN.
- Blue and green target-group ARNs.
- Blue and green EC2 instance IDs.

Use exact names from the checked-in workflow. Keep secret values out of logs and source files.

## 8. Continuous deployment

The CD workflow is triggered by successful completion of the named CI workflow on `main`, and supports manual dispatch with a full image SHA.

The deployment stages are:

1. Resolve the image URI.
2. Assume the AWS role using OIDC.
3. Read the ALB listener's weighted forward action.
4. Identify the active target group (highest weight) and inactive target group.
5. Ensure both groups are attached to the listener with active weight 100 and inactive weight 0.
6. Identify the EC2 instance registered in the inactive target group.
7. Send an SSM Run Command to deploy the new ECR image.
8. Wait for the inactive target to become healthy in the ALB.
9. Promote the new target group to weight 100 and set the previous active group to weight 0.
10. If validation or promotion fails, execute the configured rollback behavior.

The workflow uses SSM Run Command rather than opening SSH from the GitHub runner. The EC2 instance must be online in Systems Manager and have the necessary permissions and network connectivity to retrieve the image.

## 9. Troubleshooting CI/CD

| Symptom | Checks |
|---|---|
| OIDC assume-role fails | Verify provider, role trust policy, GitHub subject condition, audience, role ARN, and workflow permissions for `id-token: write` |
| Variable resolves empty | Check the job's `environment:` and the exact variable name and scope |
| ECR login/push fails | Check repository name, region, account ID, and role permissions |
| Image tag not found | Confirm the CI publish job succeeded and the SHA is exactly the one CD is deploying |
| SSM command remains pending | Check instance SSM managed-node status, instance profile, SSM agent, and network access |
| SSM command fails | Inspect command invocation stdout/stderr and the remote shell commands |
| New target is unhealthy | Check container status, Nginx listen port, host/container port mapping, target-group port, health-check path, and security groups |
| Traffic does not switch | Inspect listener actions, target health, and the CD promotion step |

Useful SSM commands:

```bash
aws ssm describe-instance-information --region us-east-1 --output table
aws ssm list-commands --region us-east-1 --output table
```

For a specific command, inspect its invocation with the command ID and instance ID shown in the workflow output:

```bash
aws ssm get-command-invocation \
  --command-id COMMAND_ID \
  --instance-id INSTANCE_ID \
  --region us-east-1
```
