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

### Demo Apps

#### 2048 game

```
cd tf-k8s/game-2048
terraform init
terraform apply

kubectl port-forward service/service-2048 8080:80
```

#### Prometheus + Grafana

https://archive.eksworkshop.com/intermediate/240_monitoring/deploy-prometheus/

```
kubectl apply -f k8s/storageclass-gp3.yaml

kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus prometheus-community/prometheus --namespace prometheus 
    
kubectl get all -n prometheus

kubectl port-forward -n prometheus deploy/prometheus-server 8080:9090
```

```
helm repo add grafana https://grafana.github.io/helm-charts

kubectl create namespace grafana

helm install grafana grafana/grafana --namespace grafana --set persistence.enabled=true --values grafana-datasources.yaml
    
kubectl get all -n grafana

kubectl port-forward -n grafana deploy/grafana 3000:3000
```

Import dashboard 3119 (Kubernetes Cluster Monitoring (via Prometheus))

### Alternative

```
helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.enabled=true \
    --set adminPassword='EKS!sAWSome' \
    --set service.type=LoadBalancer \
    --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
    --values grafana-datasources.yaml
```