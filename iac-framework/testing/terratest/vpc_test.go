package test

import (
	"testing"
	"fmt"
	"strings"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestVPCModule validates the VPC module functionality
func TestVPCModule(t *testing.T) {
	t.Parallel()

	// Generate a random suffix for unique resource names
	uniqueId := random.UniqueId()
	vpcName := fmt.Sprintf("test-vpc-%s", uniqueId)
	awsRegion := "us-west-2"

	// Configure Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/vpc",
		Vars: map[string]interface{}{
			"vpc_name":             vpcName,
			"vpc_cidr":             "10.0.0.0/16",
			"availability_zones":   []string{"us-west-2a", "us-west-2b", "us-west-2c"},
			"public_subnet_cidrs":  []string{"10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"},
			"private_subnet_cidrs": []string{"10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"},
			"enable_nat_gateway":   true,
			"enable_dns_hostnames": true,
			"enable_dns_support":   true,
			"tags": map[string]string{
				"Environment": "test",
				"Project":     "terratest",
				"Owner":       "infrastructure-team",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the VPC module
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	internetGatewayId := terraform.Output(t, terraformOptions, "internet_gateway_id")

	// Verify VPC was created
	assert.NotEmpty(t, vpcId, "VPC ID should not be empty")
	
	// Verify VPC exists in AWS
	vpc := aws.GetVpcById(t, vpcId, awsRegion)
	assert.Equal(t, "10.0.0.0/16", *vpc.CidrBlock, "VPC CIDR should match")
	
	// Verify DNS settings
	assert.True(t, *vpc.EnableDnsSupport, "DNS support should be enabled")
	assert.True(t, *vpc.EnableDnsHostnames, "DNS hostnames should be enabled")

	// Verify public subnets
	assert.Len(t, publicSubnetIds, 3, "Should have 3 public subnets")
	for i, subnetId := range publicSubnetIds {
		subnet := aws.GetSubnetById(t, subnetId, awsRegion)
		assert.True(t, *subnet.MapPublicIpOnLaunch, "Public subnet should auto-assign public IPs")
		expectedCidr := fmt.Sprintf("10.0.%d.0/24", (i+1))
		assert.Equal(t, expectedCidr, *subnet.CidrBlock, "Public subnet CIDR should match")
	}

	// Verify private subnets
	assert.Len(t, privateSubnetIds, 3, "Should have 3 private subnets")
	for i, subnetId := range privateSubnetIds {
		subnet := aws.GetSubnetById(t, subnetId, awsRegion)
		assert.False(t, *subnet.MapPublicIpOnLaunch, "Private subnet should not auto-assign public IPs")
		expectedCidr := fmt.Sprintf("10.0.%d0.0/24", (i+1))
		assert.Equal(t, expectedCidr, *subnet.CidrBlock, "Private subnet CIDR should match")
	}

	// Verify Internet Gateway
	assert.NotEmpty(t, internetGatewayId, "Internet Gateway ID should not be empty")
	
	// Verify tags
	vpcTags := aws.GetTagsForVpc(t, vpcId, awsRegion)
	assert.Equal(t, "test", vpcTags["Environment"], "Environment tag should match")
	assert.Equal(t, "terratest", vpcTags["Project"], "Project tag should match")
	assert.Equal(t, "infrastructure-team", vpcTags["Owner"], "Owner tag should match")
}

// TestVPCWithoutNATGateway tests VPC creation without NAT Gateway
func TestVPCWithoutNATGateway(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	vpcName := fmt.Sprintf("test-vpc-no-nat-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/vpc",
		Vars: map[string]interface{}{
			"vpc_name":             vpcName,
			"vpc_cidr":             "10.1.0.0/16",
			"availability_zones":   []string{"us-west-2a", "us-west-2b"},
			"public_subnet_cidrs":  []string{"10.1.1.0/24", "10.1.2.0/24"},
			"private_subnet_cidrs": []string{"10.1.10.0/24", "10.1.20.0/24"},
			"enable_nat_gateway":   false,
			"enable_dns_hostnames": true,
			"enable_dns_support":   true,
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "no-nat",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify NAT Gateway was not created
	natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	assert.Empty(t, natGatewayIds, "NAT Gateway should not be created when disabled")
}

// TestVPCCustomCIDR tests VPC with custom CIDR ranges
func TestVPCCustomCIDR(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	vpcName := fmt.Sprintf("test-vpc-custom-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/vpc",
		Vars: map[string]interface{}{
			"vpc_name":             vpcName,
			"vpc_cidr":             "172.16.0.0/16",
			"availability_zones":   []string{"us-west-2a"},
			"public_subnet_cidrs":  []string{"172.16.1.0/24"},
			"private_subnet_cidrs": []string{"172.16.10.0/24"},
			"enable_nat_gateway":   true,
			"single_nat_gateway":   true,
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "custom-cidr",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify custom CIDR
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	vpc := aws.GetVpcById(t, vpcId, awsRegion)
	assert.Equal(t, "172.16.0.0/16", *vpc.CidrBlock, "Custom VPC CIDR should match")

	// Verify single NAT Gateway
	natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	assert.Len(t, natGatewayIds, 1, "Should have exactly one NAT Gateway")
}

// TestVPCValidation tests input validation
func TestVPCValidation(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	vpcName := fmt.Sprintf("test-vpc-validation-%s", uniqueId)
	awsRegion := "us-west-2"

	// Test with mismatched subnet count
	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/vpc",
		Vars: map[string]interface{}{
			"vpc_name":             vpcName,
			"vpc_cidr":             "10.0.0.0/16",
			"availability_zones":   []string{"us-west-2a", "us-west-2b"},
			"public_subnet_cidrs":  []string{"10.0.1.0/24"},  // Only 1 subnet
			"private_subnet_cidrs": []string{"10.0.10.0/24"}, // Only 1 subnet
			"enable_nat_gateway":   true,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// This should fail due to validation
	_, err := terraform.InitAndApplyE(t, terraformOptions)
	if err == nil {
		// Clean up if it somehow succeeded
		terraform.Destroy(t, terraformOptions)
		t.Error("Expected validation error for mismatched subnet counts")
	}
}

// TestVPCEndpoints tests VPC endpoint creation
func TestVPCEndpoints(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	vpcName := fmt.Sprintf("test-vpc-endpoints-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/vpc",
		Vars: map[string]interface{}{
			"vpc_name":             vpcName,
			"vpc_cidr":             "10.0.0.0/16",
			"availability_zones":   []string{"us-west-2a", "us-west-2b"},
			"public_subnet_cidrs":  []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_subnet_cidrs": []string{"10.0.10.0/24", "10.0.20.0/24"},
			"enable_nat_gateway":   true,
			"enable_vpc_endpoints": true,
			"vpc_endpoints": []string{
				"s3",
				"ec2",
				"ssm",
			},
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "vpc-endpoints",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC endpoints were created
	vpcEndpointIds := terraform.OutputList(t, terraformOptions, "vpc_endpoint_ids")
	assert.Len(t, vpcEndpointIds, 3, "Should have 3 VPC endpoints")

	// Verify S3 endpoint is gateway type
	s3EndpointId := terraform.Output(t, terraformOptions, "s3_endpoint_id")
	assert.NotEmpty(t, s3EndpointId, "S3 endpoint should be created")
}

// Helper function to test tags
func validateResourceTags(t *testing.T, expectedTags map[string]string, actualTags map[string]string) {
	for key, expectedValue := range expectedTags {
		actualValue, exists := actualTags[key]
		assert.True(t, exists, fmt.Sprintf("Tag %s should exist", key))
		assert.Equal(t, expectedValue, actualValue, fmt.Sprintf("Tag %s value should match", key))
	}
}

// TestVPCFlowLogs tests VPC Flow Logs configuration
func TestVPCFlowLogs(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	vpcName := fmt.Sprintf("test-vpc-flow-logs-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/vpc",
		Vars: map[string]interface{}{
			"vpc_name":             vpcName,
			"vpc_cidr":             "10.0.0.0/16",
			"availability_zones":   []string{"us-west-2a"},
			"public_subnet_cidrs":  []string{"10.0.1.0/24"},
			"private_subnet_cidrs": []string{"10.0.10.0/24"},
			"enable_nat_gateway":   true,
			"enable_flow_logs":     true,
			"flow_logs_destination": "cloudwatch",
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "flow-logs",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify flow logs were created
	flowLogId := terraform.Output(t, terraformOptions, "flow_log_id")
	assert.NotEmpty(t, flowLogId, "Flow log should be created")

	// Verify CloudWatch log group was created
	logGroupName := terraform.Output(t, terraformOptions, "flow_log_group_name")
	assert.NotEmpty(t, logGroupName, "Flow log group should be created")
	assert.True(t, strings.Contains(logGroupName, "vpc-flow-logs"), "Log group name should contain vpc-flow-logs")
}