output "namespace" {
  description = "Istio system namespace"
  value       = kubernetes_namespace.istio_system.metadata[0].name
}

output "gateway_external_ip" {
  description = "External IP of the Istio Gateway"
  value       = try(helm_release.istio_ingress.status[0].load_balancer[0].ingress[0].ip, null)
}

output "gateway_service_name" {
  description = "Name of the Istio Gateway service"
  value       = "istio-ingress"
}

output "istiod_service_name" {
  description = "Name of the Istiod service"
  value       = "istiod"
}

output "mesh_id" {
  description = "Mesh ID"
  value       = var.mesh_id
}

output "network_name" {
  description = "Network name"
  value       = var.network_name
}