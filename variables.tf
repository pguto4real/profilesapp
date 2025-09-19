variable "github_token" {
  description = "GitHub personal access token for Amplify connection"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "Full HTTPS URL of your GitHub repository"
  type        = string
}

variable "app_name" {
  description = "Name of the Amplify app"
  type        = string
  default     = "profilesapp"
}