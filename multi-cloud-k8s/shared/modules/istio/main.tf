terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
    labels = {
      name = "istio-system"
    }
  }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      pilot = {
        traceSampling = var.trace_sampling
        resources = {
          requests = {
            cpu    = var.pilot_cpu_request
            memory = var.pilot_memory_request
          }
          limits = {
            cpu    = var.pilot_cpu_limit
            memory = var.pilot_memory_limit
          }
        }
      }
      global = {
        meshID = var.mesh_id
        multiCluster = {
          clusterName = var.cluster_name
        }
        network = var.network_name
      }
    })
  ]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name

  values = [
    yamlencode({
      service = {
        type = var.gateway_service_type
        ports = [
          {
            name       = "http2"
            port       = 80
            protocol   = "TCP"
            targetPort = 8080
          },
          {
            name       = "https"
            port       = 443
            protocol   = "TCP"
            targetPort = 8443
          }
        ]
      }
      resources = {
        requests = {
          cpu    = var.gateway_cpu_request
          memory = var.gateway_memory_request
        }
        limits = {
          cpu    = var.gateway_cpu_limit
          memory = var.gateway_memory_limit
        }
      }
    })
  ]

  depends_on = [helm_release.istiod]
}

resource "kubernetes_manifest" "peer_authentication" {
  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    spec = {
      mtls = {
        mode = var.mtls_mode
      }
    }
  }

  depends_on = [helm_release.istiod]
}

resource "kubernetes_manifest" "destination_rule" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.istio_system.metadata[0].name
    }
    spec = {
      host = "*.local"
      trafficPolicy = {
        tls = {
          mode = "ISTIO_MUTUAL"
        }
      }
    }
  }

  depends_on = [helm_release.istiod]
}