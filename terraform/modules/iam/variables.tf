variable "github_owner" {
  description = "GitHub username or organization that owns the repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the GitHub Actions IAM role"
  type        = string
  default     = "main"
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository used by the application"
  type        = string
}
