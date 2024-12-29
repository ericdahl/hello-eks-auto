# hello-eks-auto

Demo of using EKS Auto Mode

See https://aws.amazon.com/blogs/aws/streamline-kubernetes-cluster-management-with-new-amazon-eks-auto-mode/

## Quick Start

```
git clone git@github.com:ericdahl/hello-eks-auto.git
cd hello-eks-auto

terraform apply
aws eks update-kubeconfig --name hello-eks-auto

cd k8s/
kubectl apply -f ingressclass.yaml
```
