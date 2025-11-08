provider "aws" {
  region = var.region

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

