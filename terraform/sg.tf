# Control plane security group
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Node security group
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "EKS worker nodes security group"
  vpc_id      = aws_vpc.main.id
  

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nodes-sg"
  })
}

# Rules: nodes talk to each other freely
resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.nodes.id
  security_group_id        = aws_security_group.nodes.id
  description              = "Allow all internal node-to-node communication"
}

# Control plane can reach nodes (for webhook calls, metrics)
resource "aws_security_group_rule" "cluster_to_nodes" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.nodes.id
  description              = "Allow control plane to reach nodes"
}

# Nodes can reach the API server (port 443)
resource "aws_security_group_rule" "nodes_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow nodes to communicate with API server"
}

# Nodes outbound — all traffic (for pulling images, AWS APIs)
resource "aws_security_group_rule" "nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "Allow all outbound from nodes"
}

resource "aws_security_group" "lb_sg" {
  description = "[k8s] Shared Backend SecurityGroup for LoadBalancer"
  
}
resource "aws_security_group" "lb_sg2" {
  description = "[k8s] Managed SecurityGroup for LoadBalancer"
  
}