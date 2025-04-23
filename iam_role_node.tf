resource "aws_iam_role" "node" {
  name = "eks-auto-node-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodeMinimalPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryPullOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.node.name
}

data "aws_iam_policy" "eks_inline" {
  name = "EKSInlineNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_inline" {
  policy_arn = data.aws_iam_policy.eks_inlimne.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy" "node_custom_bad_policy" {
  name = "BadNodePolicy"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DesribeInstances",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}
