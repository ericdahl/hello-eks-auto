provider "kubernetes" {
  config_path = "~/.kube/config" # Adjust path as needed
}

# Namespace
resource "kubernetes_namespace" "loki" {
  metadata {
    name = "loki"
  }
}

# Loki StatefulSet
resource "kubernetes_stateful_set" "loki" {
  metadata {
    name      = "loki"
    namespace = kubernetes_namespace.loki.metadata[0].name
    labels = {
      app     = "loki"
      release = "loki"
    }
  }

  spec {
    replicas = 1
    service_name = "loki-headless"

    selector {
      match_labels = {
        app     = "loki"
        release = "loki"
      }
    }

    template {
      metadata {
        labels = {
          app     = "loki"
          release = "loki"
        }

        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "3100"
        }
      }

      spec {
        service_account_name = "loki"
        containers {
          name  = "loki"
          image = "grafana/loki:2.9.8"

          args = [
            "-config.file=/etc/loki/loki.yaml"
          ]

          ports {
            name           = "http-metrics"
            container_port = 3100
            protocol       = "TCP"
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = "http-metrics"
            }
            initial_delay_seconds = 45
            period_seconds        = 10
            timeout_seconds       = 1
          }

          volume_mounts {
            name       = "config"
            mount_path = "/etc/loki"
          }

          volume_mounts {
            name       = "storage"
            mount_path = "/data"
          }
        }

        volumes {
          name = "config"
          secret {
            secret_name = "loki"
          }
        }

        volumes {
          name     = "storage"
          empty_dir {}
        }
      }
    }
  }
}

# Loki Service
resource "kubernetes_service" "loki" {
  metadata {
    name      = "loki"
    namespace = kubernetes_namespace.loki.metadata[0].name
    labels = {
      app     = "loki"
      release = "loki"
    }
  }

  spec {
    selector = {
      app     = "loki"
      release = "loki"
    }

    ports {
      name       = "http-metrics"
      port       = 3100
      target_port = "http-metrics"
    }
    type = "ClusterIP"
  }
}

# Promtail DaemonSet
resource "kubernetes_daemonset" "promtail" {
  metadata {
    name      = "loki-promtail"
    namespace = kubernetes_namespace.loki.metadata[0].name
    labels = {
      app     = "promtail"
      release = "loki"
    }
  }

  spec {
    selector {
      match_labels = {
        app     = "promtail"
        release = "loki"
      }
    }

    template {
      metadata {
        labels = {
          app     = "promtail"
          release = "loki"
        }
      }

      spec {
        service_account_name = "loki-promtail"
        containers {
          name  = "promtail"
          image = "grafana/promtail:2.9.3"

          args = [
            "-config.file=/etc/promtail/promtail.yaml"
          ]

          ports {
            name           = "http-metrics"
            container_port = 3101
            protocol       = "TCP"
          }

          volume_mounts {
            name       = "config"
            mount_path = "/etc/promtail"
          }

          volume_mounts {
            name       = "pods"
            mount_path = "/var/log/pods"
            read_only  = true
          }
        }

        volumes {
          name = "config"
          secret {
            secret_name = "loki-promtail"
          }
        }

        volumes {
          name = "pods"
          host_path {
            path = "/var/log/pods"
          }
        }
      }
    }
  }
}