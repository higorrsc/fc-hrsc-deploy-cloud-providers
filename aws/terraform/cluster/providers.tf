terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket         = "codeflix-terraform"
    key            = "states/terraform.cluster.tfstate"
    dynamodb_table = "tf-state-locking"
  }
}

provider "aws" {
  region = "us-east-2"
}
