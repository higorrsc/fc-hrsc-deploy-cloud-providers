locals {
  cluster_name = "fc-hrsc"
}

# Criação da VPC e Subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name = "fc-hrsc-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name                                          = "fc-hrsc-vpc"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

# Criação do cluster EKS
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.10.0"
  cluster_name    = local.cluster_name
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-load-balancer-controller = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    ng-app = {
      instance_types = ["t3.medium"]
      min_size       = 4
      max_size       = 4
      desired_size   = 4
      labels = {
        type = "ec2"
      }
    }
  }

  # IAM roles for service accounts
  iam_role_for_service_accounts = {
    # Required for EBS CSI driver
    ebs_csi = {
      attach_ebs_csi_policy = true
    }
    # Required for AWS Load Balancer Controller
    aws_load_balancer_controller = {
      attach_load_balancer_controller_policy = true
    }
  }
}
