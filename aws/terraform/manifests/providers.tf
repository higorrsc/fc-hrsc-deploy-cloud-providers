terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }
  }

  backend "s3" {
    bucket         = "codeflix-terraform"
    key            = "states/terraform.manifests.tfstate"
    dynamodb_table = "tf-state-locking"
  }
}

data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = "codeflix-terraform"
    key    = "states/terraform.cluster.tfstate"
    region = "us-east-2"
  }
}

data "terraform_remote_state" "crds" {
  backend = "s3"
  config = {
    bucket = "codeflix-terraform"
    key    = "states/terraform.crds.tfstate"
    region = "us-east-2"
  }
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.cluster.outputs.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.cluster.outputs.cluster_name
}

provider "aws" {
  region = "us-east-2"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
