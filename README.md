# hello-eks-auto

Demo of EKS Auto Mode, which streamlines Kubernetes cluster management on AWS. See [AWS Blog Post](https://aws.amazon.com/blogs/aws/streamline-kubernetes-cluster-management-with-new-amazon-eks-auto-mode/).

also has ECS comparison

## Quick Start

### Deploy AWS Infrastructure
```bash
terraform init
terraform apply
aws eks update-kubeconfig --name hello-eks-auto
```

### Deploy Kubernetes Resources
```bash
cd tf-k8s/
terraform init
terraform apply
```

## Demo Applications

### 2048 Game
```bash
cd tf-k8s/game-2048
terraform init
terraform apply
kubectl port-forward service/service-2048 8080:80
```

### Storage Class
```bash
kubectl apply -f k8s/storageclass-gp3.yaml
```

### Monitoring & Logging

#### Grafana
```bash
kubectl create namespace grafana
kubectl apply -f k8s/grafana-simple.yaml -n grafana
kubectl port-forward -n grafana deploy/grafana 3000:3000
```
Login: admin/admin

#### Loki
```bash
kubectl create namespace loki
kubectl apply -f k8s/storageclass-gp3.yaml
kubectl apply -f k8s/loki-simple.yaml -n loki
```

#### Promtail
```bash
kubectl apply -f k8s/promtail-helm.yaml -n loki
```

#### Prometheus
```bash
kubectl create namespace prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus --namespace prometheus
kubectl port-forward -n prometheus deploy/prometheus-server 8080:9090
```
Useful dashboard: 3119 (Kubernetes Cluster Monitoring)

## Alternative Installation Options

### Grafana via Helm
```bash
kubectl create namespace grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana --namespace grafana --set persistence.enabled=true
kubectl port-forward -n grafana deploy/grafana 3000:3000
```

### Promtail via Helm
```bash
helm install promtail grafana/promtail -n loki
```

## Troubleshooting Notes

### Loki + Grafana Compatibility
Grafana 10+ switched Loki health check to PromQL with `vector(1)+vector(1)`, but this depends on a feature missing in older Loki versions.

Compatibility matrix:
- Grafana 9.1.7: works with Loki 2.6.1
- Grafana 10.x/11.x: requires newer Loki
