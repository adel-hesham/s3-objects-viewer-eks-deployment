resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn

  # ALWAYS private subnets for nodes
  subnet_ids = [
    aws_subnet.private_AZ1.id,
    aws_subnet.private_AZ2.id,
  ]
  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1 # during updates, max 1 node down at a time
  }

  # Use EKS-optimized Amazon Linux 2 AMI
  ami_type      = "AL2_x86_64"
  capacity_type = "ON_DEMAND" # or SPOT for cost savings in dev
  disk_size     = 20          # GB per node

  labels = {
    environment = var.environment
    role        = "worker"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy,
  ]

  tags = local.common_tags
}