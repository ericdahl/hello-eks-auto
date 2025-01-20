# hello-eks-auto

Demo of using EKS Auto Mode

See https://aws.amazon.com/blogs/aws/streamline-kubernetes-cluster-management-with-new-amazon-eks-auto-mode/

# TODO
- get promtail working
- split promtail into separate deploy

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

#### Storage Class (optional)

- newer
- default `kubernetes.io/aws-ebs` gp2 is deprecated

```
kubectl apply -f k8s/storageclass-gp3.yaml
```

#### Grafana

##### Option 1: k8s yaml - simple

- no persistence
- Service is ClusterIP
- login admin/admin

```
kubectl create namespace grafana
kubectl apply -f k8s/grafana-simple.yaml -n grafana
kubectl port-forward -n grafana deploy/grafana 3000:3000
```

##### Option 2: helm chart

- persistence
- sets admin password in k8s Secret

```
kubectl create namespace grafana

helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana --namespace grafana --set persistence.enabled=true --values grafana-datasources.yaml   

kubectl port-forward -n grafana deploy/grafana 3000:3000
```

##### Option 3: helm chart with LoadBalancer

```
helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.enabled=true \
    --set adminPassword='EKS!sAWSome' \
    --set service.type=LoadBalancer \
    --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
    --values grafana-datasources.yaml
```

#### Prometheus

https://archive.eksworkshop.com/intermediate/240_monitoring/deploy-prometheus/

```


kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus prometheus-community/prometheus --namespace prometheus 
    
kubectl get all -n prometheus

kubectl port-forward -n prometheus deploy/prometheus-server 8080:9090
```


Import dashboard 3119 (Kubernetes Cluster Monitoring (via Prometheus))



### Loki + Promtail

#### Option 1 - helm chart (very outdated)

- standard helm install, but..
- using extremely outdated loki 2.6.1 (why?)

```
kubectl create namespace loki
helm install loki grafana/loki-stack --namespace loki
```

http://loki.loki.svc.cluster.local:3100

TODO:
- helm chart very outdated. why? broken API compatibility
- swap to TF/yaml ?

https://github.com/grafana/loki/issues/12931

dashboard 14055

dashboard 13639 Logs/App - basic

##### Debugging

TL;DR: Grafana 10+ switched loki health check to PromQL with `vector(1)+vector(1)` but this
depends on a Loki feature which doesn't exist in 2.6.1 - https://github.com/grafana/loki/issues/6946

`loki-stack-2.10.2` has dependency on `loki` `^2.15.2` which resolves to sub-chart `loki-2.16.0` which is
3 years old and points to loki 2.6.1

Looks like `loki-stack` is entirely obsolete and not maintained (2 years now)

```

Grafana 11.4
loki 2.6.1

tcpdump on grafana pod

```
GET /loki/api/v1/query?direction=backward&query=vector%281%29%2Bvector%281%29&time=4000000000 HTTP/1.1
Host: loki.loki.svc.cluster.local:3100
User-Agent: Grafana/11.4.0
X-Datasource-Uid: cealcflva7ls0c
X-Grafana-Id: eyJhbGciOiJFUzI1NiIsImtpZCI6ImlkLTIwMjUtMDEtZXMyNTYiLCJ0eXAiOiJqd3QifQ.eyJhdWQiOiJvcmc6MSIsImF1dGhlbnRpY2F0ZWRCeSI6InBhc3N3b3JkIiwiZW1haWwiOiJhZG1pbkBsb2NhbGhvc3QiLCJleHAiOjE3Mzc0MDQxOTYsImlhdCI6MTczNzQwMzU5NiwiaWRlbnRpZmllciI6ImRlYWxjZDQ5b3R2Y3diIiwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDozMDAwLyIsIm5hbWVzcGFjZSI6ImRlZmF1bHQiLCJzdWIiOiJ1c2VyOjEiLCJ0eXBlIjoidXNlciIsInVzZXJuYW1lIjoiYWRtaW4ifQ.SGzeSEhz_jS5XDzs_5-uQozgLXyrN7B5GfYQJefN9pu6o2RI1smxOLMRmG-jT5xK_yarJCig2lVq6LQaklKqIA
X-Grafana-Org-Id: 1
X-Loki-Response-Encoding-Flags: categorize-labels
Accept-Encoding: gzip

...

HTTP/1.1 400 Bad Request
Content-Type: application/json; charset=UTF-8
Date: Mon, 20 Jan 2025 20:07:12 GMT
Content-Length: 65
```

Other versions
- grafana
  - 11.1.9 - same issue
  - 10.4.14 - same issue
  - 9.1.7 - works
- Grafana commit - https://github.com/grafana/grafana/commit/a40302760800aef0c31511ff5830f329ac6c3b4b

```
GET /loki/api/v1/labels?start=1737404699015000000&end=1737405299015000000 HTTP/1.1
Host: loki.loki.svc.cluster.local:3100
User-Agent: Grafana/9.1.7
Accept-Encoding: gzip


...
HTTP/1.1 200 OK
Content-Type: application/json
Date: Mon, 20 Jan 2025 20:34:59 GMT
Content-Length: 115

{"status":"success","data":["app","container","filename","instance","job","namespace","node_name","pod","stream"]}
```