terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.31.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "kuar" {
  metadata {
    name = "kuar"
  }
}

resource "kubernetes_deployment" "kuar" {
  metadata {
    name      = "kuar"
    namespace = kubernetes_namespace.kuar.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "kuar"
      }
    }

    template {
      metadata {
        labels = {
          app = "kuar"
        }
      }

      spec {
        container {
          name  = "kuar"
          image = "gcr.io/kuar-demo/kuard-amd64:blue"

          port {
            container_port = 8080
          }

          resources {
            limits = {
                cpu    = "0.1"
                memory = "32Mi"
            }
          }


          liveness_probe {
            http_get {
              path = "/healthy"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}