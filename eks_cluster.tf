resource "aws_eks_cluster" "default" {
  name = local.name

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  bootstrap_self_managed_addons = false

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true

    subnet_ids = [
      # using public subnets to save money on NAT gateways and simplicity; not recommended for production
      aws_subnet.public["us-east-1a"].id,
      aws_subnet.public["us-east-1b"].id,
      aws_subnet.public["us-east-1c"].id,
    ]

  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,
  ]
}

resource "aws_eks_access_entry" "default" {
  cluster_name  = aws_eks_cluster.default.name
  principal_arn = var.access_entry_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "default" {
  cluster_name  = aws_eks_cluster.default.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = aws_eks_access_entry.default.principal_arn

  access_scope {
    type = "cluster"
  }
}