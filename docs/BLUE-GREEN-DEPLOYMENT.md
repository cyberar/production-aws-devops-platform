# Blue-Green Deployment and Rollback

## 1. What blue-green deployment means

Blue-green deployment maintains two application environments. One environment serves production traffic while the other receives the next release. The new release is deployed and validated before the load balancer sends production traffic to it.

In this project:
- Blue is represented by `production-blue-tg` and its registered EC2 instance.
- Green is represented by `production-green-tg` and its registered EC2 instance.
- The ALB listener controls traffic distribution using target-group weights.

Blue and green are environment labels. Either one can be active.

## 2. Why both target groups remain attached

The inactive target group must be associated with the ALB listener to be eligible for ALB health checking. The CD workflow therefore uses a weighted forward action with both target groups attached.

Typical steady state:

| Target group | Weight |
|---|---:|
| Active environment | 100 |
| Inactive environment | 0 |

This sends production traffic to the active environment while keeping the other group attached and available for health evaluation.

## 3. Deployment sequence

1. CI builds, scans, and publishes the image to ECR.
2. CD reads the listener action and identifies the group with the highest weight as active.
3. CD identifies the other group as inactive.
4. CD ensures both target groups are attached with active 100 / inactive 0.
5. CD finds the EC2 instance registered in the inactive target group.
6. SSM pulls and runs the new image on that instance.
7. The deployment preserves the previous image reference when one exists.
8. CD polls ALB target health until the new target becomes healthy or the timeout is reached.
9. If healthy, CD updates the listener weights to new 100 / previous 0.
10. The deployment completes with the new environment serving traffic.

## 4. Port mapping is critical

The application container's Nginx process listens on port 8080. The deployment maps EC2 host port 80 to container port 8080:

```bash
-p 80:8080
```

The ALB target group connects to the EC2 instance on port 80. It does not connect directly to container port 8080.

The Dockerfile must configure Nginx to listen on 8080. The default Nginx configuration can contain whitespace between `listen` and `80`, so a narrowly matched text replacement may fail silently. Verify the effective configuration during image build or on the container.

Useful checks:

```bash
docker ps
docker port CONTAINER_NAME
docker logs CONTAINER_NAME
```

From the EC2 host, test the published host port:

```bash
curl -i http://localhost/
```

## 5. Health validation

The ALB target group health check is configured for HTTP on the target's traffic port, with path `/` and expected status 200 in the documented deployment.

Inspect health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN \
  --region us-east-1 \
  --output json
```

Common target states and reasons:
- `healthy`: health checks are passing.
- `unhealthy` / `Target.FailedHealthChecks`: the target is failing health checks.
- `unused` / `Target.NotInUse`: the target group may not be associated with a listener rule, or the target may not be in use for another reason. Inspect listener association and target-group configuration.

Do not promote traffic just because the container process is running. The ALB must report the target healthy.

## 6. Rollback behavior

The workflow has rollback handling at more than one stage.

### Local deployment failure

If the new container fails to start, the remote deployment script's error trap attempts to restore the previous container image if a saved previous-image reference exists. If the instance has no saved previous image (for example, a first deployment), the failed container is removed; there may be no prior local image to restore.

### ALB health-check failure

If the newly deployed target does not become healthy before the validation timeout, the workflow sends an SSM rollback command to restore the saved previous image where available. The deployment fails rather than promoting an unhealthy target.

### Listener promotion failure

The promotion step has an error handler that attempts to restore the previous listener weights if the listener update fails. This preserves the previous production routing when possible.

Rollback is best-effort and must be verified in the AWS environment. A successful rollback command is not a substitute for checking container state, target health, and listener weights.

## 7. Verification commands

Get the ALB ARN:

```bash
aws elbv2 describe-load-balancers \
  --names production-devops-alb \
  --region us-east-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text
```

Inspect listener weights:

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn ALB_ARN \
  --region us-east-1 \
  --query 'Listeners[*].DefaultActions' \
  --output json
```

Inspect both target groups:

```bash
for TG in production-blue-tg production-green-tg; do
  echo "===== $TG ====="
  ARN=$(aws elbv2 describe-target-groups \
    --names "$TG" \
    --region us-east-1 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  aws elbv2 describe-target-health \
    --target-group-arn "$ARN" \
    --region us-east-1 \
    --output table
done
```

A completed deployment should have the newly active target group at weight 100 and healthy. The previous group should be at weight 0. Ideally, both remain healthy so that the previous environment is ready for a quick return.

## 8. Safe rollback test

Perform rollback tests only in an environment where a failed release is safe. Before testing:
- Confirm the currently active target group and its weight.
- Confirm both target groups' health.
- Confirm the inactive instance has the expected previous image available if the test relies on restoring it.
- Record the current image and listener configuration.
- Use a deliberately invalid or failing test release only if the workflow's failure path can be triggered without affecting users.
- After the test, verify the previous image is running, the previous target is healthy, and listener weights still route production traffic to the known-good environment.

Do not deliberately break the active production environment to test rollback.
