# Infrastructure as Code Framework

A comprehensive, production-ready infrastructure framework built with Terraform, providing reusable modules, governance, automation, and testing capabilities.

## 🏗️ Architecture Overview

This framework provides a complete infrastructure-as-code solution with:

- **Reusable Terraform Modules**: Pre-built, tested modules for common infrastructure patterns
- **Policy as Code**: Automated compliance and governance using OPA and Sentinel
- **GitOps Workflows**: Automated CI/CD pipelines with GitHub Actions and Atlantis
- **Cost Optimization**: Built-in cost monitoring and optimization with Infracost and Cloud Custodian
- **Security Scanning**: Comprehensive security scanning with Checkov, TFSec, and Semgrep
- **Infrastructure Testing**: Thorough testing framework using Terratest and Kitchen-Terraform

## 📁 Project Structure

```
iac-framework/
├── modules/                    # Reusable Terraform modules
│   └── aws/
│       ├── vpc/               # VPC module with networking
│       └── ec2/               # EC2 module with security
├── examples/                  # Example deployments
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── use-cases/
├── policies/                  # Policy as Code
│   ├── opa/                   # Open Policy Agent rules
│   └── sentinel/              # Sentinel policies
├── workflows/                 # GitOps automation
│   ├── github-actions/        # GitHub Actions workflows
│   └── atlantis/              # Atlantis configuration
├── cost-optimization/         # Cost management
│   ├── infracost/             # Cost estimation
│   └── cloud-custodian/       # Cost optimization policies
├── security/                  # Security scanning
│   ├── checkov/               # Checkov configuration
│   ├── tfsec/                 # TFSec configuration
│   └── semgrep/               # Custom security rules
├── testing/                   # Infrastructure testing
│   ├── terratest/             # Go-based testing
│   └── kitchen-terraform/     # Ruby-based testing
└── scripts/                   # Deployment utilities
```

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate permissions
- [Go](https://golang.org/doc/install) >= 1.21 (for Terratest)
- [Ruby](https://www.ruby-lang.org/en/documentation/installation/) >= 3.0 (for Kitchen-Terraform)

### Basic Usage

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd iac-framework
   ```

2. **Configure your environment:**
   ```bash
   export AWS_REGION=us-west-2
   export AWS_PROFILE=your-profile
   ```

3. **Deploy infrastructure:**
   ```bash
   # Plan deployment
   ./scripts/deploy.sh --environment dev --module vpc --action plan
   
   # Apply changes
   ./scripts/deploy.sh --environment dev --module vpc --action apply --auto-approve
   ```

## 📦 Terraform Modules

### VPC Module

Comprehensive VPC setup with public/private subnets, NAT gateways, and optional VPC endpoints.

```hcl
module "vpc" {
  source = "./modules/aws/vpc"
  
  vpc_name             = "my-vpc"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  
  enable_nat_gateway = true
  enable_flow_logs   = true
  
  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

**Features:**
- Multi-AZ deployment across 2-3 availability zones
- Public and private subnets with customizable CIDR blocks
- Optional NAT Gateway (single or per-AZ)
- VPC Flow Logs for network monitoring
- VPC Endpoints for AWS services
- Comprehensive tagging strategy

### EC2 Module

Flexible EC2 instance deployment with security best practices.

```hcl
module "ec2" {
  source = "./modules/aws/ec2"
  
  instance_name       = "web-server"
  instance_type       = "t3.medium"
  ami_id              = "ami-0c02fb55956c7d316"
  subnet_id           = module.vpc.private_subnet_ids[0]
  security_group_ids  = [module.vpc.default_security_group_id]
  
  enable_monitoring       = true
  root_volume_encrypted   = true
  create_iam_role        = true
  
  tags = {
    Environment = "production"
    Application = "web"
  }
}
```

**Features:**
- Multiple instance deployment support
- Encrypted EBS volumes with customizable size and type
- IAM roles and instance profiles
- Security groups with least-privilege access
- CloudWatch monitoring integration
- Spot instance support
- User data script execution

## 🔒 Security & Compliance

### Security Scanning

The framework includes comprehensive security scanning:

```bash
# Run all security scans
checkov -d modules/ --framework terraform
tfsec modules/
semgrep --config=security/semgrep/semgrep-rules.yaml modules/
```

### Policy as Code

**Open Policy Agent (OPA):**
- AWS security policies
- Resource tagging enforcement
- Cost optimization rules

**Sentinel:**
- Terraform plan validation
- Compliance checking
- Custom business rules

### Security Features

- **Encryption**: All storage encrypted at rest
- **Network Security**: Private subnets, security groups, NACLs
- **IAM**: Least-privilege access, role-based permissions
- **Monitoring**: VPC Flow Logs, CloudWatch, CloudTrail integration
- **Compliance**: CIS, SOC2, PCI DSS, GDPR compliance checks

## 💰 Cost Optimization

### Infracost Integration

Generate cost estimates for infrastructure changes:

```bash
infracost breakdown --config-file=cost-optimization/infracost/infracost-config.yml
```

### Cloud Custodian Policies

Automated cost optimization:
- Stop dev instances after hours
- Delete unattached EBS volumes
- Right-size underutilized instances
- Lifecycle policies for S3 storage

### Cost Features

- **Budgets**: Environment-specific cost limits
- **Alerts**: Automated cost anomaly detection
- **Optimization**: Right-sizing recommendations
- **Governance**: Cost center allocation and approval workflows

## 🔄 GitOps & Automation

### GitHub Actions

Automated CI/CD pipeline in `.github/workflows/terraform-ci-cd.yml`:

- **Pull Request**: Plan and validate changes
- **Merge to Main**: Apply to staging
- **Release**: Deploy to production
- **Security**: Automated security scanning
- **Cost**: Cost impact analysis

### Atlantis

GitOps for Terraform with `workflows/atlantis/atlantis.yaml`:

- **Pull Request Automation**: Plan on PR creation
- **Policy Enforcement**: OPA/Sentinel validation
- **Approval Workflows**: Multi-stage approvals
- **State Management**: Remote state with locking

## 🧪 Testing Framework

### Terratest (Go-based)

```bash
cd testing/terratest
make test
```

**Test Coverage:**
- VPC connectivity and routing
- EC2 instance configuration
- Security group rules
- IAM permissions
- Cost optimization

### Kitchen-Terraform (Ruby-based)

```bash
cd testing/kitchen-terraform
bundle install
kitchen test all
```

**Test Suites:**
- Infrastructure compliance
- Security validation
- Performance testing
- Disaster recovery scenarios

## 📊 Monitoring & Observability

### CloudWatch Integration

- **Metrics**: Custom dashboards for infrastructure health
- **Alarms**: Automated alerting for critical issues
- **Logs**: Centralized logging with log aggregation

### Cost Monitoring

- **Real-time Tracking**: Cost and usage monitoring
- **Anomaly Detection**: Automated cost spike alerts
- **Optimization Reports**: Regular right-sizing recommendations

## 🚀 Deployment Guide

### Environment Setup

1. **Development Environment:**
   ```bash
   ./scripts/deploy.sh --environment dev --module all --action apply
   ```

2. **Staging Environment:**
   ```bash
   ./scripts/deploy.sh --environment staging --module all --action apply
   ```

3. **Production Environment:**
   ```bash
   ./scripts/deploy.sh --environment prod --module all --action plan
   # Review plan carefully
   ./scripts/deploy.sh --environment prod --module all --action apply --auto-approve
   ```

### Multi-Environment Strategy

- **Development**: Cost-optimized, relaxed security
- **Staging**: Production-like, testing-focused
- **Production**: High-availability, security-hardened

## 🔧 Configuration

### Environment Variables

```bash
export AWS_REGION=us-west-2
export AWS_PROFILE=your-profile
export TF_STATE_BUCKET=your-terraform-state-bucket
export TF_STATE_LOCK_TABLE=your-terraform-lock-table
```

### Terraform Variables

Configure in `environments/{env}/terraform.tfvars`:

```hcl
# Common settings
environment  = "production"
project_name = "my-project"
aws_region   = "us-west-2"

# VPC configuration
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]
enable_nat_gateway  = true

# Tags
tags = {
  Environment = "production"
  Project     = "my-project"
  Owner       = "infrastructure-team"
  CostCenter  = "engineering"
}
```

## 📈 Scaling & Performance

### High Availability

- **Multi-AZ Deployment**: Resources distributed across AZs
- **Auto Scaling**: Automatic capacity management
- **Load Balancing**: Traffic distribution
- **Backup & Recovery**: Automated backup strategies

### Performance Optimization

- **Instance Types**: Right-sized for workload requirements
- **Storage**: Optimized EBS volume types (gp3, io2)
- **Networking**: Enhanced networking, placement groups
- **Monitoring**: Performance metrics and alerting

## 🔍 Troubleshooting

### Common Issues

1. **State Lock Issues:**
   ```bash
   terraform force-unlock <lock-id>
   ```

2. **Permission Errors:**
   ```bash
   aws sts get-caller-identity
   aws iam get-user
   ```

3. **Module Dependencies:**
   ```bash
   terraform graph | dot -Tpng > dependencies.png
   ```

### Debug Mode

Enable verbose logging:
```bash
export TF_LOG=DEBUG
./scripts/deploy.sh --verbose --environment dev --module vpc --action plan
```

## 🤝 Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Testing

```bash
# Run all tests
make test

# Run specific test suites
make test-vpc
make test-ec2
make test-security
```

### Code Standards

- **Terraform**: Follow HashiCorp best practices
- **Go**: Use `go fmt` and `golint`
- **Ruby**: Follow RuboCop guidelines
- **Documentation**: Update README and module docs

## 📚 Additional Resources

### Documentation

- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Infrastructure as Code Patterns](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html)

### Tools & References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Kitchen-Terraform](https://newcontext-oss.github.io/kitchen-terraform/)
- [Infracost](https://www.infracost.io/)
- [Cloud Custodian](https://cloudcustodian.io/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Support

For support and questions:

- Create an issue in the repository
- Contact the infrastructure team
- Review the troubleshooting guide

---

**Built with ❤️ for reliable, scalable, and secure infrastructure automation.**