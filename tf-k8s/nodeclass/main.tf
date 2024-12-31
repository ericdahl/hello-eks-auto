provider "kubernetes" {
    config_path = "~/.kube/config"
}


resource "kubernetes_manifest" "node_class" {
  manifest = {
    "apiVersion" = "eks.amazonaws.com/v1"
    "kind"       = "NodeClass"
    "metadata" = {
      "name" = "private-compute"
    }
    "spec" = {
      "ephemeralStorage" = {
        "size" = "160Gi"
      }
    }
  }
}