# Terraform EKS Infrastructure

This Terraform configuration provisions a complete AWS infrastructure for deploying an Amazon Elastic Kubernetes Service (EKS) cluster. The infrastructure includes networking components, compute resources, IAM roles, and persistent storage required for running containerized applications.

## Overview

This module creates the following AWS resources:

- Virtual Private Cloud (VPC) with public and private subnets across multiple availability zones
- Amazon EKS cluster with managed node groups
- IAM roles and policies for cluster and worker node operations
- Elastic Block Store (EBS) volume for persistent database storage
- Network components including Internet Gateway, NAT Gateway, and route tables

## Prerequisites

Before using this Terraform configuration, ensure the following requirements are met:

- AWS account with appropriate permissions (AdministratorAccess recommended for initial setup)
- AWS CLI installed and configured with valid credentials
- Terraform installed (version 1.0 or higher)
- kubectl installed for cluster interaction (optional, for post-deployment verification)

## Quick Start

### Step 1: Verify AWS Configuration

Verify that AWS CLI is properly configured and credentials are valid:

```bash
aws sts get-caller-identity
```

This command should return your AWS account ID, user ARN, and user ID.

### Step 2: Initialize Terraform

Navigate to the project directory and initialize Terraform:

```bash
cd /Users/mohamedelsharkawy/Documents/Personal/terraform-eks
terraform init
```

This command downloads the required providers and modules.

### Step 3: Review Configuration

Preview the resources that will be created:

```bash
terraform plan
```

Review the output carefully to understand what resources will be provisioned.

### Step 4: Deploy Infrastructure

Apply the Terraform configuration to create the infrastructure:

```bash
terraform apply
```

Type `yes` when prompted. The deployment process typically takes 10-15 minutes, as EKS cluster creation is an asynchronous operation.

### Step 5: Configure kubectl

After successful deployment, configure kubectl to connect to the cluster:

```bash
aws eks update-kubeconfig --name AutoOps-cluster --region eu-north-1
```

Replace `eu-north-1` with the AWS region specified in your configuration.

### Step 6: Verify Cluster

Verify that the cluster is operational:

```bash
kubectl get nodes
```

The output should show worker nodes in `Ready` status.

## Configuration Files

This section provides detailed documentation for each Terraform configuration file.

### main.tf

The main configuration file sets up Terraform itself, including provider requirements and version constraints.

**Terraform Configuration:**
- Minimum Terraform version: 1.0 or higher (recommended for stability)
- AWS provider version: 5.x (latest stable)

**Provider Configuration:**
- AWS provider is configured to use the region specified in `variables.tf`
- Optional: Multiple AWS account support via profile configuration

**Backend Configuration:**
- Remote state storage via S3 backend is available but commented out by default
- For team collaboration, uncomment and configure the S3 backend section

### variables.tf

This file defines input variables that allow customization without modifying code directly.

**AWS Region Variable:**
- Description: AWS region where all resources will be created
- Type: String
- Default: `eu-north-1`
- Override: Can be overridden via command line: `terraform apply -var="aws_region=us-east-1"`

**Common AWS Regions:**
- `us-east-1` (N. Virginia) - Lowest cost, most services available
- `eu-central-1` (Frankfurt) - Good for European deployments
- `eu-north-1` (Stockholm) - Current default
- `ap-southeast-1` (Singapore) - Good for Asia-Pacific deployments

**Finding Your Region:**
1. Check the AWS Console in the top-right corner
2. Run: `aws configure get region`
3. Check where existing team resources are located

### vpc.tf

This file creates the Virtual Private Cloud (VPC) and networking infrastructure. The VPC serves as an isolated network environment, similar to a private data center, and provides the networking foundation for the EKS cluster.

**VPC Configuration:**
- Name: `AutoOps-vpc` (appears in AWS Console)
- CIDR Block: `10.0.0.0/16` (provides 65,536 IP addresses from 10.0.0.0 to 10.0.255.255)

**Availability Zones:**
- Two availability zones are used for high availability
- AZs are automatically derived from the configured region (e.g., `eu-north-1a`, `eu-north-1b`)
- If a region uses different AZ naming conventions, update the `azs` variable accordingly
- To find available AZs: `aws ec2 describe-availability-zones --region <region>`

**Public Subnets:**
- Two public subnets with direct internet access via Internet Gateway
- CIDR ranges: `10.0.1.0/24` and `10.0.2.0/24` (256 IPs each)
- Used for: Load Balancers, NAT Gateway, Bastion hosts

**Private Subnets:**
- Two private subnets with no direct internet access (enhanced security)
- CIDR ranges: `10.0.3.0/24` and `10.0.4.0/24` (256 IPs each)
- Used for: EKS worker nodes, databases, internal services
- EKS nodes access the internet via NAT Gateway for pulling container images

**NAT Gateway:**
- Enables outbound internet access for resources in private subnets
- Required for EKS nodes to download container images from Docker Hub or Nexus
- Single NAT Gateway configuration (cost-effective)
- For production with high traffic, consider one NAT Gateway per AZ (more expensive but provides better performance and redundancy)

**DNS Configuration:**
- DNS hostnames and DNS support are enabled
- Required for EKS to resolve Kubernetes service names

**Tags:**
- All resources are tagged with Name, Project (AutoOps), and ManagedBy (Terraform) for better organization and cost tracking

### eks.tf

This file creates the Amazon Elastic Kubernetes Service (EKS) cluster. EKS is a managed Kubernetes service where AWS handles the control plane, allowing focus on application deployment.

**Cluster Configuration:**
- Cluster Name: `AutoOps-cluster` (used to identify the cluster in AWS Console)
- Kubernetes Version: `1.29` (stable version)
- To check supported versions: `aws eks list-versions`

**Endpoint Access:**
- Public access is enabled for the cluster API endpoint
- Required for kubectl commands from local machines
- For production environments, consider disabling public access and using VPN or bastion hosts

**VPC Integration:**
- Cluster is created within the VPC defined in `vpc.tf`
- Worker nodes are placed in private subnets for security
- VPC ID and subnet IDs are automatically referenced from the VPC module

**IAM Role Configuration:**
- Custom IAM role is used (created in `iam.tf`)
- The `create_iam_role` flag is set to `false` to use the pre-created role
- Cluster IAM role ARN is referenced from the IAM role resource

**Worker Node Groups:**
- Managed node groups provide EC2 instances that run container workloads
- Instance Type: `t3.medium` (2 vCPU, 4GB RAM) - cost-effective for testing
- For production workloads with 1500-3000 concurrent users, consider `t3.large` or `t3.xlarge`
- Scaling Configuration:
  - Minimum nodes: 1 (cluster always maintains at least one node)
  - Maximum nodes: 3 (supports Horizontal Pod Autoscaler scaling)
  - Desired nodes: 1 (initial cluster state)
- Disk Size: 20GB per node (sufficient for OS and container images)
- IAM Role: Worker nodes use the IAM role defined in `iam.tf`

**Tags:**
- Cluster and node groups are tagged for identification and cost allocation

### iam.tf

This file creates IAM roles and policies required for EKS to function properly. These roles enable the cluster and worker nodes to interact with AWS services.

**EKS Cluster IAM Role:**
- Role Name: `eks-cluster-role`
- Purpose: Attached to the EKS control plane (managed by AWS)
- Permissions: Allows the cluster to create and manage AWS resources including:
  - Load balancers (for Kubernetes services)
  - CloudWatch logs (for cluster logging)
  - Other services required for Kubernetes operations
- Trust Policy: Allows the EKS service (`eks.amazonaws.com`) to assume this role

**Attached Policies:**
- `AmazonEKSClusterPolicy`: Provides cluster permissions to manage AWS resources
- `AmazonEKSVPCResourceController`: Allows EKS to manage Elastic Network Interfaces (ENIs) for pods

**EKS Node Group IAM Role:**
- Role Name: `eks-node-role`
- Purpose: Attached to each EC2 instance running as a worker node
- Permissions: Enables nodes to:
  - Pull container images from Amazon ECR
  - Write logs to CloudWatch
  - Access EBS volumes for persistent storage
  - Communicate with other AWS services
- Trust Policy: Allows EC2 instances (`ec2.amazonaws.com`) to assume this role

**Attached Policies:**
- `AmazonEKSWorkerNodePolicy`: Grants nodes permissions to join the cluster
- `AmazonEKS_CNI_Policy`: Allows nodes to manage networking for pods (Container Network Interface)
- `AmazonEC2ContainerRegistryReadOnly`: Enables nodes to pull images from ECR
- `CloudWatchAgentServerPolicy`: Permits nodes to send logs to CloudWatch

**Tags:**
- All IAM roles are tagged for identification and compliance tracking

### ebs.tf

This file creates an Elastic Block Store (EBS) volume for persistent database storage. EBS provides block-level storage that persists independently of EC2 instance lifecycles.

**Volume Configuration:**
- Purpose: Persistent storage for MySQL StatefulSet deployments
- Availability Zone: Must match one of the private subnets where MySQL pods will run
- Current AZ: First availability zone of the configured region (e.g., `eu-north-1a`)
- Important: MySQL StatefulSet pods must be scheduled in the same AZ as the EBS volume

**Volume Specifications:**
- Size: 50GB (provides room for database growth)
- Type: `gp3` (General Purpose SSD - latest generation with best performance/cost ratio)
- Alternative types:
  - `gp2`: Older general purpose SSD
  - `io1/io2`: Provisioned IOPS for high-performance databases
  - `st1`: Throughput optimized for large sequential workloads
- Encryption: Enabled at rest (security best practice)

**Tags:**
- Volume is tagged with Name, Project, ManagedBy, and Purpose
- Purpose tag (`MySQL-PersistentStorage`) helps identify the volume for Kubernetes PersistentVolume creation

**Post-Deployment Steps:**
After Terraform creates this volume, the following Kubernetes resources need to be created:
1. StorageClass that references this EBS volume type
2. PersistentVolume (PV) that uses the volume ID (available in outputs)
3. PersistentVolumeClaim (PVC) in the MySQL StatefulSet configuration

### outputs.tf

This file defines output values that are displayed after successful deployment. These outputs are essential for configuring other components of the infrastructure.

**Cluster Information:**
- `cluster_endpoint`: URL to connect to the Kubernetes cluster API (e.g., `https://ABC123.yl4.eu-north-1.eks.amazonaws.com`)
- `cluster_name`: Name of the EKS cluster, used in kubectl commands and kubeconfig configuration
- `cluster_security_group_id`: Security group ID that controls network access to the cluster (useful for Ingress/Load Balancer configuration)

**Network Information:**
- `vpc_id`: ID of the VPC where all resources are deployed (useful for reference and troubleshooting)
- `private_subnets`: List of private subnet IDs where EKS worker nodes are running (needed for service configurations)
- `public_subnets`: List of public subnet IDs (used for Load Balancers, NAT Gateway, and potential Jenkins/Nexus deployments)

**IAM Information:**
- `node_group_role_name`: IAM role name attached to worker nodes (useful for troubleshooting permissions)
- `node_group_role_arn`: Full ARN of the node group role (sometimes needed for advanced configurations)

**Storage Information:**
- `ebs_volume_id`: ID of the EBS volume for MySQL database (e.g., `vol-0a1b2c3d4e5f6g7h8`)
- `ebs_volume_az`: Availability Zone where the EBS volume is located (critical: MySQL pods must be scheduled in the same AZ)

**Utility Output:**
- `configure_kubectl`: Pre-formatted command to configure kubectl to connect to the cluster (can be copy-pasted)

## Outputs

After successful deployment, Terraform displays the following outputs:

- `cluster_endpoint` - URL to connect to Kubernetes API
- `cluster_name` - Name of the EKS cluster
- `cluster_security_group_id` - Security group ID for cluster access
- `vpc_id` - VPC ID
- `private_subnets` - List of private subnet IDs
- `public_subnets` - List of public subnet IDs
- `node_group_role_name` - IAM role name for worker nodes
- `node_group_role_arn` - IAM role ARN for worker nodes
- `ebs_volume_id` - EBS volume ID for MySQL database
- `ebs_volume_az` - Availability Zone of the EBS volume
- `configure_kubectl` - Command to configure kubectl

## Integration with Other Components

### Kubernetes Deployment Team

The following outputs are required for Kubernetes deployments:

- `cluster_endpoint` and `cluster_name` - For kubectl configuration and cluster connection
- `ebs_volume_id` - For creating PersistentVolume resources for MySQL StatefulSet
- `ebs_volume_az` - Critical for ensuring MySQL pods are scheduled in the correct availability zone
- `private_subnets` - For service and ingress configurations
- `cluster_security_group_id` - For configuring Ingress controllers and Load Balancers

### CI/CD and Infrastructure Team

The following outputs are useful for CI/CD pipeline setup:

- `public_subnets` - For deploying Jenkins, Nexus, or other CI/CD tools on EC2 instances
- `vpc_id` - For network configuration and security group management
- `cluster_endpoint` - For automated deployment pipelines

## Troubleshooting

### Access Denied Errors

**Symptoms:** Terraform fails with "Access Denied" or permission errors.

**Solutions:**
- Verify IAM user has `AdministratorAccess` policy attached
- Check AWS credentials: `aws sts get-caller-identity`
- Ensure credentials are not expired

### Region Not Available

**Symptoms:** Error indicating region does not support EKS or resources are unavailable.

**Solutions:**
- Verify region supports EKS: https://aws.amazon.com/eks/features/regions/
- Update `variables.tf` with a supported region
- Check region-specific service availability

### Insufficient Capacity

**Symptoms:** Error indicating insufficient capacity in availability zone.

**Solutions:**
- Try a different availability zone
- Use a different instance type
- Wait and retry (capacity may be temporarily unavailable)

### kubectl Connection Issues

**Symptoms:** Unable to connect to cluster using kubectl.

**Solutions:**
- Run: `aws eks update-kubeconfig --name AutoOps-cluster --region <region>`
- Verify security groups allow access from your IP address
- Check cluster endpoint public access is enabled
- Verify IAM user has permissions to describe the cluster

## Cost Estimation

Approximate monthly costs (varies by region and usage):

- EKS Cluster Control Plane: ~$72/month
- t3.medium Worker Node (1 node): ~$30/month
- NAT Gateway: ~$32/month
- EBS Volume (50GB gp3): ~$5/month
- Data Transfer: Variable based on usage

**Estimated Total:** ~$140/month for a basic testing setup

**Cost Optimization:**
- Use `t3.small` instead of `t3.medium` (saves ~$15/month)
- Delete NAT Gateway when not actively testing (saves ~$32/month)
- Use single availability zone instead of multi-AZ (reduces NAT Gateway and data transfer costs)
- Scale down node groups during non-business hours

## Destroying Infrastructure

To remove all created resources:

```bash
terraform destroy
```

Type `yes` when prompted. The destruction process typically takes 5-10 minutes.

**Warning:** This operation permanently deletes all resources created by this Terraform configuration, including:
- EKS cluster and all workloads
- Worker nodes and their data
- EBS volumes and all stored data
- VPC and networking components
- IAM roles (if not used elsewhere)

Ensure all important data is backed up before destroying the infrastructure.

## File Structure

```
terraform-eks/
├── main.tf          # Terraform and AWS provider configuration
├── variables.tf     # Input variables (region, etc.)
├── vpc.tf           # VPC, subnets, NAT Gateway configuration
├── eks.tf           # EKS cluster and node groups configuration
├── iam.tf           # IAM roles and policies for cluster and nodes
├── ebs.tf           # EBS volume for MySQL persistent storage
├── outputs.tf       # Output values for integration with other components
└── README.md        # This documentation file
```

## Pre-Deployment Checklist

Before running `terraform apply`, verify:

- [ ] AWS CLI is configured and credentials are valid (`aws sts get-caller-identity` works)
- [ ] Terraform is installed (`terraform version` shows 1.0 or higher)
- [ ] AWS region in `variables.tf` matches the intended deployment region
- [ ] Cluster name in `eks.tf` is appropriate and unique
- [ ] Instance type in `eks.tf` meets performance requirements
- [ ] EBS volume size in `ebs.tf` is sufficient for database needs
- [ ] AWS account has sufficient service quotas and credits
- [ ] Sufficient time allocated for deployment (10-15 minutes)

## Additional Resources

- [Terraform AWS EKS Module Documentation](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## License

This configuration is provided as-is for the AutoOps project.

---

**Project:** AutoOps  
**Maintained by:** Infrastructure Team  
**Last Updated:** December 2025
