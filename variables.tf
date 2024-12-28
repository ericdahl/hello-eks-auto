variable "availability_zones" {
  default = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
  ]
}

# normally would default this to current identity but if using SSO, the role ARN format is different
variable "access_entry_principal_arn" {}