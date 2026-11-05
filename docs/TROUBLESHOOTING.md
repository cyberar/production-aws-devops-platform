# Troubleshooting Guide

This document records common issues encountered while implementing and operating this project. Always inspect the current workflow, Dockerfile, Terraform configuration, and AWS resource state before applying a fix.

## 1. ALB target reports `Target.FailedHealthChecks`

**Meaning:** The ALB cannot get the expected successful response from the registered target.

Check target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN \
  --region us-east-1 \
  --output json
```

Check:
1. Is the Docker container running?
2. Does Nginx listen on the expected container port?
3. Does Docker publish EC2 host port 80 to container port 8080?
4. Does the target group use EC2 port 80?
5. Does the health-check path return HTTP 200?
6. Does the EC2 security group allow port 80 from the ALB security group?

For this project, the container port mapping is:

```bash
-p 80:8080
```

A previous failure was caused by the Nginx default configuration continuing to listen on port 80 inside the container when the deployment expected port 8080. The original `sed` expression did not match the whitespace in the default configuration (`listen       80;`). The image therefore built but the application did not listen on the port Docker was forwarding to.

Inspect the effective Nginx config inside a test container:

```bash
docker run --rm --entrypoint sh IMAGE_URI -c \
  "grep -n 'listen' /etc/nginx/conf.d/default.conf"
```

The expected listen directive is `listen 8080;`.

## 2. Target reports `Target.NotInUse`

**Meaning:** The target is not currently in use by the load balancer. A common cause in this project was that the inactive target group was not associated with the listener when health validation was attempted.

Inspect target-group association:

```bash
aws elbv2 describe-target-groups \
  --target-group-arns BLUE_TG_ARN GREEN_TG_ARN \
  --region us-east-1 \
  --query 'TargetGroups[*].[TargetGroupName,LoadBalancerArns]' \
  --output json
```

Inspect listener actions:

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[*].DefaultActions' \
  --output json
```

The deployment workflow should attach both target groups to the listener before waiting for the inactive target's health, with the active group at weight 100 and inactive at weight 0.

## 3. Nginx starts but ALB health checks fail

Check the complete port chain:

```text
ALB target group -> EC2 host port 80 -> Docker published port 80:8080 -> Nginx container port 8080
```

Do not change the target-group port to 8080 unless the EC2 host is actually listening on that port and the security group allows it. The documented deployment uses EC2 port 80 and container port 8080.

## 4. Docker container exits or cannot start

Inspect:

```bash
docker ps -a
docker logs CONTAINER_NAME
docker inspect CONTAINER_NAME
```

Check the image's Nginx configuration, command, user permissions, writable runtime paths, and port binding. The project Dockerfile uses a non-root Nginx user and a PID file under `/tmp`; changes to these paths can affect startup.

## 5. GitHub Actions cannot assume the AWS role

Check:
- Workflow has the required OIDC token permission (`id-token: write`).
- AWS IAM OIDC provider exists and has the correct audience.
- IAM role trust policy matches the repository and branch/environment subject.
- Workflow uses the intended role ARN.
- The selected GitHub Environment is the one containing the configured variables.

Do not solve an OIDC trust-policy mismatch by adding permanent AWS access keys to the repository.

## 6. GitHub Actions variable is empty

A job-level GitHub Environment selection affects which environment variables and secrets are available. Confirm the `environment:` value in the workflow and place the variable in that exact environment or intentionally change the workflow scope.

Check spelling and capitalization. GitHub variable names are case-sensitive in workflow expressions.

## 7. ECR image cannot be found

Confirm the image was published and that CD is using the same full commit SHA:

```bash
aws ecr describe-images \
  --repository-name production-devops-app \
  --region us-east-1 \
  --output table
```

A successful pull-request CI run does not necessarily publish an image. Confirm the main-branch publish job completed.

## 8. SSM deployment command fails

Check managed-instance registration:

```bash
aws ssm describe-instance-information \
  --region us-east-1 \
  --output table
```

Inspect the command and invocation output:

```bash
aws ssm list-commands --region us-east-1 --output table

aws ssm get-command-invocation \
  --command-id COMMAND_ID \
  --instance-id INSTANCE_ID \
  --region us-east-1 \
  --output json
```

Confirm the EC2 instance role includes the required SSM permissions, the SSM agent is running, and the instance can reach required AWS endpoints and ECR.

## 9. Listener does not switch traffic

Inspect the listener's weighted target groups and confirm the newly deployed target is healthy. The deployment should not promote an unhealthy target. Check the CD logs for the promotion command and its error handler.

## 10. Alarm does not send an email

Check:
1. SNS subscription status is `Confirmed`.
2. Alarm action points to the correct SNS topic ARN.
3. The alarm actually entered `ALARM` (a forced state change can be used for a controlled delivery test).
4. Alarm history shows the state transition.
5. Email spam/junk folder and mail filtering.

## 11. General diagnostic sequence

When a deployment fails, work from the outside inward:

1. Inspect GitHub Actions job and step logs.
2. Confirm the expected image exists in ECR.
3. Inspect SSM command status and output.
4. Inspect Docker container state and logs on the target instance.
5. Test the application on the EC2 host port.
6. Inspect ALB target health and reason.
7. Inspect listener target-group weights.
8. Confirm production traffic remains on the known-good target group.

Capture the exact command output and resource identifiers before changing infrastructure. Avoid making several changes at once; isolate the cause and verify each fix.
