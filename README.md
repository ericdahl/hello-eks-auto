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
- rely on default storage class


https://archive.eksworkshop.com/intermediate/240_monitoring/deploy-prometheus/

```
kubectl apply -f k8s/storageclass-gp3.yaml

kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="auto-ebs-sc" \
    --set server.persistentVolume.storageClass="auto-ebs-sc"
    
kubectl get all -n prometheus

kubectl port-forward -n prometheus deploy/prometheus-server 8080:9090
```

```
helm repo add grafana https://grafana.github.io/helm-charts

kubectl create namespace grafana

helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.storageClassName="auto-ebs-sc" \
    --set persistence.enabled=true \
    --set adminPassword='EKS!sAWSome' \
    --set service.type=LoadBalancer \
    --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
    --values grafana.yaml
    
kubectl get all -n grafana

kubectl port-forward -n grafana deploy/grafana 3000:3000
```