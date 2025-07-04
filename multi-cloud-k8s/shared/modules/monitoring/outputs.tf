output "namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_endpoint" {
  description = "Prometheus endpoint"
  value       = "http://prometheus-kube-prometheus-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_endpoint" {
  description = "Grafana endpoint"
  value       = "http://prometheus-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
}

output "alertmanager_endpoint" {
  description = "Alertmanager endpoint"
  value       = "http://prometheus-kube-prometheus-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093"
}

output "jaeger_endpoint" {
  description = "Jaeger Query endpoint"
  value       = "http://jaeger-query.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:16686"
}

output "elasticsearch_endpoint" {
  description = "Elasticsearch endpoint"
  value       = "http://elasticsearch-master.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9200"
}