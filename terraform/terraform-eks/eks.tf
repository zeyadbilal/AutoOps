module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.1"

  cluster_name                    = "AutoOps-cluster"
  cluster_version                 = "1.29"
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_iam_role = false
  iam_role_arn    = aws_iam_role.eks_cluster_role.arn

  enable_cluster_creator_admin_permissions = true

  access_entries = {
    terraform-admin = {
      principal_arn = "arn:aws:iam::486027076915:user/terraform-admin"
      type          = "STANDARD"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = ["t3.micro"]
      iam_role_name  = aws_iam_role.eks_node_role.name
      disk_size      = 20

      tags = {
        Name      = "eks-node-default"
        Project   = "AutoOps"
        ManagedBy = "Terraform"
      }
    }
  }

  tags = {
    Name      = "AutoOps-cluster"
    Project   = "AutoOps"
    ManagedBy = "Terraform"
  }
}
