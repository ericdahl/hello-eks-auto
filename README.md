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

### Prometheus

TODO:
- use gp3


https://archive.eksworkshop.com/intermediate/240_monitoring/deploy-prometheus/

```
kubectl apply -f k8s/storageclass-gp2.yaml

kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"
```

```
helm repo add grafana https://grafana.github.io/helm-charts

helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set persistence.enabled=true \
    --set adminPassword='EKS!sAWSome' \
    --set service.type=LoadBalancer \
    --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
    --values grafana.yaml
```