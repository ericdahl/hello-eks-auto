provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Name       = "hello-eks-auto"
      Repository = "https://github.com/ericdahl/hello-eks-auto"
    }
  }
}

data "aws_default_tags" "default" {}

locals {
  name = data.aws_default_tags.default.tags["Name"]
}