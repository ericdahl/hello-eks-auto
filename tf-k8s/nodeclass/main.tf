provider "kubernetes" {
    config_path = "~/.kube/config"
}


resource "kubernetes_manifest" "nodeclass_private_compute" {
  manifest = {
    "apiVersion" = "eks.amazonaws.com/v1"
    "kind"       = "NodeClass"
    "metadata" = {
      "name" = "private-compute"
    }

    # https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html
    # docs suggest these are optional fields but actually are required
    "spec" = {
      "role" = "eks-auto-node-example"
      "securityGroupSelectorTerms" = [
        {
          "tags" = {
            "aws:eks:cluster-name" = "hello-eks-auto"
          }
        }
      ]
      "subnetSelectorTerms" = [
        {
          "tags" = {
            "kubernetes.io/role" = "node"
          }
        }
      ]
      "ephemeralStorage" = {
        "size" = "16Gi"
      }
    }
  }
}