# Makefile for Terratest Infrastructure Testing

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod

# Test parameters
TEST_TIMEOUT=60m
TEST_PARALLEL=4
VERBOSE=-v

# AWS parameters
AWS_REGION ?= us-west-2
AWS_PROFILE ?= default

# Test directories
TEST_DIR=./...
VPC_TEST_DIR=./vpc_test.go
EC2_TEST_DIR=./ec2_test.go

.PHONY: all test clean deps help

# Default target
all: test

# Help target
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  test-vpc      - Run VPC module tests"
	@echo "  test-ec2      - Run EC2 module tests"
	@echo "  test-parallel - Run tests in parallel"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  deps          - Download dependencies"
	@echo "  clean         - Clean test cache"
	@echo "  setup         - Setup test environment"
	@echo "  lint          - Run linting"
	@echo "  format        - Format code"
	@echo ""
	@echo "Environment variables:"
	@echo "  AWS_REGION    - AWS region for tests (default: us-west-2)"
	@echo "  AWS_PROFILE   - AWS profile for tests (default: default)"
	@echo "  TEST_TIMEOUT  - Test timeout (default: 60m)"
	@echo "  TEST_PARALLEL - Number of parallel tests (default: 4)"

# Download dependencies
deps:
	$(GOMOD) download
	$(GOMOD) tidy

# Run all tests
test: deps
	@echo "Running all infrastructure tests..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -parallel $(TEST_PARALLEL) $(TEST_DIR)

# Run VPC tests only
test-vpc: deps
	@echo "Running VPC module tests..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -run "TestVPC" $(VPC_TEST_DIR)

# Run EC2 tests only
test-ec2: deps
	@echo "Running EC2 module tests..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -run "TestEC2" $(EC2_TEST_DIR)

# Run tests in parallel
test-parallel: deps
	@echo "Running tests in parallel..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -parallel $(TEST_PARALLEL) $(TEST_DIR)

# Run tests with verbose output
test-verbose: deps
	@echo "Running tests with verbose output..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) -v -timeout $(TEST_TIMEOUT) -parallel $(TEST_PARALLEL) $(TEST_DIR)

# Run specific test
test-specific: deps
	@echo "Running specific test: $(TEST_NAME)"
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -run "$(TEST_NAME)" $(TEST_DIR)

# Clean test cache
clean:
	$(GOCLEAN) -testcache
	$(GOCLEAN) -cache

# Setup test environment
setup:
	@echo "Setting up test environment..."
	# Check if AWS CLI is installed
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Please install it first."; exit 1; }
	
	# Check if Terraform is installed
	@command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Please install it first."; exit 1; }
	
	# Check AWS credentials
	@aws sts get-caller-identity --profile $(AWS_PROFILE) >/dev/null 2>&1 || { echo "AWS credentials not configured for profile $(AWS_PROFILE)."; exit 1; }
	
	# Install dependencies
	$(MAKE) deps
	
	@echo "Test environment setup complete!"

# Lint Go code
lint:
	@echo "Running linting..."
	@command -v golangci-lint >/dev/null 2>&1 || { echo "golangci-lint is required but not installed. Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; exit 1; }
	golangci-lint run

# Format Go code
format:
	@echo "Formatting Go code..."
	$(GOCMD) fmt ./...

# Security scan
security:
	@echo "Running security scan..."
	@command -v gosec >/dev/null 2>&1 || { echo "gosec is required but not installed. Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest"; exit 1; }
	gosec ./...

# Run tests with coverage
test-coverage: deps
	@echo "Running tests with coverage..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) -timeout $(TEST_TIMEOUT) -parallel $(TEST_PARALLEL) -coverprofile=coverage.out $(TEST_DIR)
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run tests with race detection
test-race: deps
	@echo "Running tests with race detection..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -parallel $(TEST_PARALLEL) -race $(TEST_DIR)

# Run integration tests
test-integration: deps
	@echo "Running integration tests..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) $(VERBOSE) -timeout $(TEST_TIMEOUT) -tags=integration $(TEST_DIR)

# Run unit tests only
test-unit: deps
	@echo "Running unit tests..."
	$(GOTEST) $(VERBOSE) -timeout 10m -short $(TEST_DIR)

# Benchmark tests
bench: deps
	@echo "Running benchmark tests..."
	AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
	$(GOTEST) -timeout $(TEST_TIMEOUT) -bench=. $(TEST_DIR)

# Generate test documentation
docs:
	@echo "Generating test documentation..."
	@command -v godoc >/dev/null 2>&1 || { echo "godoc is required but not installed. Install with: go install golang.org/x/tools/cmd/godoc@latest"; exit 1; }
	godoc -http=:6060 &
	@echo "Documentation server started at http://localhost:6060"
	@echo "Press Ctrl+C to stop"

# Validate terraform modules
validate:
	@echo "Validating Terraform modules..."
	@for dir in ../../modules/aws/*/; do \
		echo "Validating $$dir"; \
		cd "$$dir" && terraform init -backend=false && terraform validate && cd - > /dev/null; \
	done

# Plan terraform modules
plan:
	@echo "Planning Terraform modules..."
	@for dir in ../../modules/aws/*/; do \
		echo "Planning $$dir"; \
		cd "$$dir" && terraform init -backend=false && terraform plan && cd - > /dev/null; \
	done

# Check for AWS resource leaks
check-leaks:
	@echo "Checking for AWS resource leaks..."
	@echo "Checking for test resources that might not have been cleaned up..."
	
	# Check for test VPCs
	@aws ec2 describe-vpcs --filters "Name=tag:Project,Values=terratest" --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table --region $(AWS_REGION) || true
	
	# Check for test instances
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=terratest" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table --region $(AWS_REGION) || true
	
	# Check for test security groups
	@aws ec2 describe-security-groups --filters "Name=tag:Project,Values=terratest" --query 'SecurityGroups[*].[GroupId,GroupName,Tags[?Key==`Name`].Value|[0]]' --output table --region $(AWS_REGION) || true

# Clean up test resources
cleanup:
	@echo "WARNING: This will attempt to clean up test resources!"
	@echo "This is a destructive operation. Press Ctrl+C to cancel or Enter to continue..."
	@read
	
	# Terminate test instances
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=terratest" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[*].Instances[*].InstanceId' --output text --region $(AWS_REGION) | xargs -r aws ec2 terminate-instances --instance-ids --region $(AWS_REGION) || true
	
	# Delete test VPCs (this is complex and should be done carefully)
	@echo "Note: VPC cleanup requires manual intervention due to dependencies"
	@echo "Please check the AWS console for remaining test resources"

# Development mode - run tests continuously
dev:
	@echo "Running tests in development mode (continuous)..."
	@command -v entr >/dev/null 2>&1 || { echo "entr is required for development mode. Install with: brew install entr (macOS) or apt-get install entr (Ubuntu)"; exit 1; }
	find . -name "*.go" | entr -r make test

# CI/CD target
ci: setup lint security test-coverage
	@echo "CI/CD pipeline completed successfully!"

# Pre-commit hook
pre-commit: format lint security test-unit
	@echo "Pre-commit checks completed successfully!"

# Show test results
results:
	@echo "Showing test results..."
	@if [ -f coverage.html ]; then \
		echo "Coverage report: coverage.html"; \
		command -v open >/dev/null 2>&1 && open coverage.html || echo "Open coverage.html in your browser"; \
	fi

# Install development tools
install-tools:
	@echo "Installing development tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	go install golang.org/x/tools/cmd/godoc@latest