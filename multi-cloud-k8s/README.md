# Multi-Cloud Kubernetes Platform

A comprehensive Infrastructure as Code (IaC) solution for deploying and managing Kubernetes clusters across multiple cloud providers (AWS, GCP, Azure) with unified monitoring, service mesh, and security policies.

## 🏗️ Architecture

This platform provides:

- **Multi-Cloud Support**: Deploy identical Kubernetes clusters on AWS EKS, Google GKE, and Azure AKS
- **Unified Monitoring**: Prometheus, Grafana, and Jaeger stack for observability
- **Service Mesh**: Istio for traffic management, security, and observability
- **Security**: Built-in security policies and mTLS encryption
- **Automation**: Scripted deployment and destruction workflows

## 📁 Project Structure

```
multi-cloud-k8s/
├── aws/                    # AWS EKS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── kubeconfig.tpl
├── gcp/                    # Google GKE infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── kubeconfig.tpl
├── azure/                  # Azure AKS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── kubeconfig.tpl
├── shared/
│   ├── modules/
│   │   ├── monitoring/     # Prometheus, Grafana, Jaeger
│   │   └── istio/         # Service mesh configuration
│   └── configs/
│       └── common.tfvars  # Shared configuration
├── scripts/
│   ├── deploy.sh          # Deployment automation
│   └── destroy.sh         # Cleanup automation
└── docs/
    └── README.md          # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Install Required Tools**:
   ```bash
   # Terraform
   brew install terraform
   
   # kubectl
   brew install kubectl
   
   # Helm
   brew install helm
   
   # Cloud CLIs
   brew install awscli      # AWS
   brew install google-cloud-sdk  # GCP
   brew install azure-cli   # Azure
   ```

2. **Configure Cloud Credentials**:
   ```bash
   # AWS
   aws configure
   
   # GCP
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   
   # Azure
   az login
   ```

### Deploy a Cluster

1. **Deploy AWS EKS cluster with monitoring and Istio**:
   ```bash
   ./scripts/deploy.sh -p aws -e dev -a -m -i
   ```

2. **Deploy GCP GKE cluster**:
   ```bash
   ./scripts/deploy.sh -p gcp -e dev -a -m -i
   ```

3. **Deploy Azure AKS cluster**:
   ```bash
   ./scripts/deploy.sh -p azure -e dev -a -m -i
   ```

### Destroy a Cluster

```bash
./scripts/destroy.sh -p aws -e dev -y
```

## 🔧 Configuration

### Common Configuration

Edit `shared/configs/common.tfvars` to customize:

```hcl
# Project configuration
project_name = "your-project"
environment  = "dev"

# Kubernetes version
kubernetes_version = "1.28"

# Monitoring configuration
prometheus_retention      = "30d"
grafana_admin_password    = "your-secure-password"

# Istio configuration
istio_version  = "1.19.0"
mtls_mode      = "STRICT"
```

### Cloud-Specific Configuration

Each cloud provider has its own `variables.tf` file with provider-specific settings:

- **AWS**: Region, instance types, VPC configuration
- **GCP**: Project ID, machine types, network configuration
- **Azure**: Location, VM sizes, virtual network configuration

## 📊 Monitoring

### Accessing Grafana

1. **Get Grafana service details**:
   ```bash
   kubectl get svc -n monitoring prometheus-grafana
   ```

2. **Port forward to access locally**:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```

3. **Access Grafana**: http://localhost:3000
   - Username: `admin`
   - Password: Set in `common.tfvars`

### Accessing Jaeger

```bash
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686
```

Access Jaeger UI: http://localhost:16686

## 🔐 Security Features

### Istio Service Mesh

- **mTLS**: Automatic mutual TLS between services
- **Traffic Policies**: Fine-grained traffic management
- **Security Policies**: Authorization and authentication

### Network Security

- **Private Subnets**: Worker nodes in private subnets
- **Security Groups**: Restrictive firewall rules
- **Network Policies**: Kubernetes network segmentation

### RBAC

- **Role-Based Access Control**: Kubernetes RBAC enabled
- **Cloud IAM Integration**: Native cloud IAM integration
- **Service Accounts**: Dedicated service accounts for workloads

## 🛠️ Advanced Usage

### Multi-Cluster Service Mesh

To connect multiple clusters in an Istio mesh:

1. **Deploy clusters in different regions/clouds**
2. **Configure cross-cluster networking**
3. **Set up Istio multi-cluster**

### Custom Helm Charts

Add custom applications to the monitoring namespace:

```bash
helm install myapp ./charts/myapp -n monitoring
```

### Terraform Modules

Extend the platform with custom modules:

```hcl
module "custom_app" {
  source = "./shared/modules/custom_app"
  
  cluster_name = var.cluster_name
  namespace    = "apps"
}
```

## 🔍 Troubleshooting

### Common Issues

1. **Terraform State Lock**:
   ```bash
   terraform force-unlock LOCK_ID
   ```

2. **kubectl Context Issues**:
   ```bash
   kubectl config current-context
   kubectl config use-context CLUSTER_NAME
   ```

3. **Helm Release Issues**:
   ```bash
   helm list -n monitoring
   helm uninstall RELEASE_NAME -n monitoring
   ```

### Debugging

1. **Check cluster status**:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

2. **Check Terraform state**:
   ```bash
   terraform show
   terraform state list
   ```

3. **View logs**:
   ```bash
   kubectl logs -f deployment/prometheus-server -n monitoring
   ```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test thoroughly**
5. **Submit a pull request**

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For support and questions:

- Create an issue in the repository
- Check the troubleshooting section
- Review cloud provider documentation

## 🎯 Roadmap

- [ ] ArgoCD integration for GitOps
- [ ] Vault integration for secrets management
- [ ] Cost optimization recommendations
- [ ] Backup and disaster recovery
- [ ] Compliance scanning integration
- [ ] Multi-region deployment support