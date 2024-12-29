# hello-eks-auto

Demo of using EKS Auto Mode

See https://aws.amazon.com/blogs/aws/streamline-kubernetes-cluster-management-with-new-amazon-eks-auto-mode/

## Quick Start

### Deploy AWS Infra
```
terraform init
terraform apply
aws eks update-kubeconfig --name hello-eks-auto
```

### Deploy k8s resources
```
cd tf-k8s/
terraform init
terraform apply
```
