provider "aws" {
  region = "us-east-1"
}


provider "aws" {
  region = "us-east-1"
  alias  = "route53_account"
}


terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 3.53"
      configuration_aliases = [aws.route53_account]
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}
