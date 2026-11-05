# CloudWatch Monitoring and SNS Notifications

## 1. Monitoring scope

The project includes a CloudWatch dashboard, six metric alarms, and an SNS email notification topic. The monitoring implemented here covers ALB target health, EC2 CPU utilization, and HTTP 5xx error counts.

This guide documents the existing implementation. Centralized EC2 log collection, CloudTrail, and expanded observability are outside this project's current scope.

## 2. Dashboard

Dashboard name:

```text
production-devops-platform
```

The dashboard contains:
- Healthy host count for blue and green target groups.
- Unhealthy host count for blue and green target groups.
- EC2 CPU utilization for blue and green instances.
- ALB request count.
- ALB target response time.
- ALB-generated and application-target-generated HTTP 5xx counts.

Open the dashboard in the AWS Console by selecting CloudWatch in `us-east-1`, then Dashboards, then `production-devops-platform`.

CLI verification:

```bash
aws cloudwatch list-dashboards \
  --region us-east-1 \
  --query "DashboardEntries[?DashboardName=='production-devops-platform']" \
  --output table
```

A graph may show no datapoints when no traffic or metric samples have been published for the selected time range. Missing data is not proof that a component is healthy.

## 3. Alarm inventory

| Alarm | Metric | Threshold | Evaluation |
|---|---|---:|---|
| `production-blue-unhealthy-targets` | `UnHealthyHostCount` for blue | >= 1 | 2 of 2 one-minute periods |
| `production-green-unhealthy-targets` | `UnHealthyHostCount` for green | >= 1 | 2 of 2 one-minute periods |
| `production-blue-high-cpu` | EC2 `CPUUtilization` | >= 80% | 1 five-minute period |
| `production-green-high-cpu` | EC2 `CPUUtilization` | >= 80% | 1 five-minute period |
| `production-alb-5xx-errors` | `HTTPCode_ELB_5XX_Count` | >= 5 | 1 five-minute period |
| `production-app-5xx-errors` | `HTTPCode_Target_5XX_Count` | >= 5 | 1 five-minute period |

The two unhealthy-host alarms use the ALB dimensions `LoadBalancer` and `TargetGroup`. CPU alarms use the EC2 `InstanceId` dimension. The 5xx alarms use the ALB dimension.

The alarms use `notBreaching` for missing data. This prevents missing datapoints alone from causing an alarm, but it also means missing metrics do not prove health. Check metric publication and dashboard data if an alarm remains in `INSUFFICIENT_DATA`.

## 4. SNS topic and email subscription

SNS topic:

```text
production-devops-alerts
```

The deployed topic ARN in the documented AWS account is:

```text
arn:aws:sns:us-east-1:292659698191:production-devops-alerts
```

Email subscriptions must be confirmed by clicking the confirmation link sent by AWS. An unconfirmed subscription will not receive alarm notifications.

List subscriptions:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:292659698191:production-devops-alerts \
  --region us-east-1 \
  --output table
```

## 5. Verify alarms

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix production- \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table
```

Alarm states:
- `OK`: The evaluated metric is not breaching the configured threshold.
- `ALARM`: The configured number of datapoints has breached the threshold.
- `INSUFFICIENT_DATA`: CloudWatch does not yet have enough data to evaluate the alarm, or metric data is missing.

## 6. Test notification delivery

A forced alarm-state change can test whether the alarm action publishes to SNS. It does not create real CPU load or make the EC2 instance unhealthy.

Example test using the Blue CPU alarm:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name production-blue-high-cpu \
  --state-value ALARM \
  --state-reason "Testing SNS email notification delivery" \
  --region us-east-1
```

Check the email inbox, including spam/junk folders. Inspect alarm history:

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name production-blue-high-cpu \
  --history-item-type StateUpdate \
  --max-records 5 \
  --region us-east-1 \
  --output table
```

A forced state is temporary: CloudWatch resumes metric evaluation and may return the alarm to the state indicated by real metric data.

## 7. Troubleshooting

| Symptom | What to check |
|---|---|
| Alarm stays `INSUFFICIENT_DATA` | Namespace, metric name, dimensions, region, and whether metrics are being published |
| No SNS email | Subscription confirmation, alarm action ARN, SNS topic, email spam folder, alarm history |
| Target-health alarm enters `ALARM` | ALB target health reason, Nginx port, container state, target-group health path, security-group path |
| CPU alarm enters `ALARM` | EC2 CPU metric and workload; inspect instance processes and application load |
| 5xx alarm enters `ALARM` | Distinguish ALB-generated errors from target-generated errors; inspect ALB target health and application/container logs |
| Dashboard graph is blank | Correct region, time range, metric dimensions, and whether datapoints exist |

## 8. Monitoring Limitations

- The current alarms are threshold-based and intentionally simple. They do not provide distributed tracing, log analytics, or full application performance monitoring.
- An `OK` alarm means the metric is currently within the configured threshold; it is not a guarantee that the entire application is error-free.
