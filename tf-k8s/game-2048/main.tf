provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_ingress_class_v1" "alb" {
  metadata {
    name = "alb"
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    controller = "eks.amazonaws.com/alb"
  }
}

resource "kubernetes_namespace" "game_2048" {
  metadata {
    name = "game-2048"
  }
}

resource "kubernetes_deployment" "deployment_2048" {
  metadata {
    name      = "deployment-2048"
    namespace = kubernetes_namespace.game_2048.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "app-2048"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "app-2048"
        }
      }

      spec {
        container {
          name  = "app-2048"
          image = "public.ecr.aws/l6m2t8p7/docker-2048:latest"
          image_pull_policy = "Always"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "service_2048" {
  metadata {
    name      = "service-2048"
    namespace = kubernetes_namespace.game_2048.metadata[0].name
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name" = "app-2048"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "ingress_2048" {
  metadata {
    name      = "ingress-2048"
    namespace = kubernetes_namespace.game_2048.metadata[0].name

    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    ingress_class_name = kubernetes_ingress_class_v1.alb.metadata[0].name

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.service_2048.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}