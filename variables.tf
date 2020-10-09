variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "credentials" {
  description = "credential location"
  default     = "$HOME/.aws/credentials"
}

variable "prefix" {
  description = "prefix for resource names"
  default     = "harlen"
}