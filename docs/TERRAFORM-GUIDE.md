# Terraform Guide

## 1. Why Terraform is used

Terraform describes infrastructure as code. Instead of creating every AWS resource manually, the project declares the desired infrastructure in configuration files. Terraform compares that configuration with its state and the real AWS environment, then proposes changes.

The project has used Terraform `>= 1.5` and AWS provider version constraint `~> 6`. The exact provider lock file in the repository is authoritative for the selected provider release.

## 2. Terraform workflow

Run these commands from the Terraform directory:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

- `init` downloads providers and initializes the working directory.
- `fmt` checks consistent Terraform formatting.
- `validate` checks configuration syntax and internal consistency.
- `plan` previews proposed infrastructure changes.
- `apply` executes the reviewed plan.

Never run `apply` without reviewing the plan, especially when it proposes replacement or deletion of networking, load-balancing, or compute resources.

## 3. Resource responsibilities

Map the descriptions below to the actual `.tf` files in the repository.

| Resource category | Responsibility |
|---|---|
| Terraform settings | Required Terraform version and provider constraints |
| AWS provider | Region and provider configuration |
| VPC | Isolated network boundary |
| Subnets | Place resources in selected Availability Zones |
| Internet gateway and routes | Provide the configured internet routing path |
| Security groups | Control inbound and outbound network traffic |
| EC2 instances | Host the blue and green application deployments |
| IAM roles and instance profiles | Grant EC2 the permissions it needs, including SSM and ECR access |
| ECR repository | Store application container images |
| ALB | Accept client traffic and forward it to target groups |
| Target groups | Register blue and green EC2 instances and perform health checks |
| Listener | Apply weighted forwarding rules |
| Outputs | Expose identifiers needed by operators and CI/CD |

## 4. Important Terraform concepts

### Providers

A provider is the plugin Terraform uses to communicate with a platform such as AWS. The AWS provider is configured with the target region. Keep the region consistent with the GitHub Actions configuration and AWS CLI commands.

### Variables

Input variables allow values such as CIDRs, instance types, and names to be changed without editing every resource block. Review variable defaults and `terraform.tfvars` handling. Do not store secrets in committed variable files.

### Resources and references

A resource block declares an AWS resource. Terraform references allow one resource to use an identifier or attribute created by another. Prefer references over hard-coded ARNs when resources are managed in the same Terraform state.

### Outputs

Outputs expose useful values such as instance IDs, target-group ARNs, ALB ARN/DNS name, and repository identifiers. Treat outputs as potentially sensitive if they contain credentials or private information; do not publish sensitive outputs.

### State

Terraform state maps configuration resources to real infrastructure. Protect state from unauthorized access and accidental deletion. Do not commit local state files or state backups to Git. For team or production use, a remote backend with locking and access control is preferable.

## 5. Safe change procedure

1. Create a feature branch.
2. Edit the relevant Terraform resource or variable.
3. Run `terraform fmt`.
4. Run `terraform validate`.
5. Run `terraform plan`.
6. Review resource replacements, deletions, and security-group changes.
7. Apply only after confirming the plan is expected.
8. Verify the resource in AWS and update documentation if the architecture changed.

## 6. Useful inspection commands

```bash
terraform version
terraform providers
terraform state list
terraform output
terraform plan
```

AWS-side inspection examples:

```bash
aws ec2 describe-instances --region us-east-1 --output table
aws elbv2 describe-load-balancers --region us-east-1 --output table
aws elbv2 describe-target-groups --region us-east-1 --output table
aws ecr describe-repositories --region us-east-1 --output table
```

`terraform state list` and `terraform output` read the current local or configured backend state. They do not independently prove that an AWS resource is healthy.
