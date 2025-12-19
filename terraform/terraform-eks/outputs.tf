output "cluster_endpoint" {
  description = "Endpoint URL for EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "node_group_role_name" {
  description = "IAM role name for EKS node group"
  value       = aws_iam_role.eks_node_role.name
}

output "node_group_role_arn" {
  description = "IAM role ARN for EKS node group"
  value       = aws_iam_role.eks_node_role.arn
}

output "ebs_volume_id" {
  description = "ID of the EBS volume for MySQL database"
  value       = aws_ebs_volume.mysql_volume.id
}

output "ebs_volume_az" {
  description = "Availability Zone of the EBS volume"
  value       = aws_ebs_volume.mysql_volume.availability_zone
}

output "configure_kubectl" {
  description = "Command to configure kubectl to connect to this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
