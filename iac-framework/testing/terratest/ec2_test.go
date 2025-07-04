package test

import (
	"testing"
	"fmt"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestEC2Module validates the EC2 module functionality
func TestEC2Module(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316", // Amazon Linux 2
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678", // This would be from VPC output
			"security_group_ids":  []string{"sg-12345678"},
			"user_data":           "",
			"enable_monitoring":   true,
			"enable_eip":          false,
			"root_volume_size":    20,
			"root_volume_type":    "gp3",
			"root_volume_encrypted": true,
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

	// We'll need to set up VPC first for a complete test
	// For now, this is the structure of the test
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	instanceId := terraform.Output(t, terraformOptions, "instance_id")
	privateIp := terraform.Output(t, terraformOptions, "private_ip")
	publicIp := terraform.Output(t, terraformOptions, "public_ip")

	// Verify instance was created
	assert.NotEmpty(t, instanceId, "Instance ID should not be empty")
	assert.NotEmpty(t, privateIp, "Private IP should not be empty")

	// Verify instance exists and is running
	ec2Instance := aws.GetEc2InstanceById(t, instanceId, awsRegion)
	assert.Equal(t, "running", *ec2Instance.State.Name, "Instance should be running")
	assert.Equal(t, "t3.micro", *ec2Instance.InstanceType, "Instance type should match")

	// Verify tags
	instanceTags := aws.GetTagsForEc2Instance(t, instanceId, awsRegion)
	assert.Equal(t, "test", instanceTags["Environment"], "Environment tag should match")
	assert.Equal(t, "terratest", instanceTags["Project"], "Project tag should match")
	assert.Equal(t, "infrastructure-team", instanceTags["Owner"], "Owner tag should match")

	// Verify root volume
	volumes := aws.GetEbsVolumesForInstance(t, instanceId, awsRegion)
	assert.Len(t, volumes, 1, "Should have one root volume")
	rootVolume := volumes[0]
	assert.Equal(t, int64(20), *rootVolume.Size, "Root volume size should be 20 GB")
	assert.Equal(t, "gp3", *rootVolume.VolumeType, "Root volume type should be gp3")
	assert.True(t, *rootVolume.Encrypted, "Root volume should be encrypted")

	// Verify monitoring is enabled
	assert.True(t, *ec2Instance.Monitoring.State == "enabled", "Monitoring should be enabled")
}

// TestEC2WithEIP tests EC2 instance with Elastic IP
func TestEC2WithEIP(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-eip-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678"},
			"enable_monitoring":   true,
			"enable_eip":          true,
			"root_volume_size":    10,
			"root_volume_type":    "gp3",
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "eip",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify EIP was created and associated
	eipId := terraform.Output(t, terraformOptions, "eip_id")
	eipPublicIp := terraform.Output(t, terraformOptions, "eip_public_ip")
	
	assert.NotEmpty(t, eipId, "EIP ID should not be empty")
	assert.NotEmpty(t, eipPublicIp, "EIP public IP should not be empty")

	// Verify the EIP is associated with the instance
	instanceId := terraform.Output(t, terraformOptions, "instance_id")
	eip := aws.GetAddressById(t, eipId, awsRegion)
	assert.Equal(t, instanceId, *eip.InstanceId, "EIP should be associated with the instance")
}

// TestEC2UserData tests EC2 instance with custom user data
func TestEC2UserData(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-userdata-%s", uniqueId)
	awsRegion := "us-west-2"

	userData := `#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from Terratest!</h1>" > /var/www/html/index.html`

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678"},
			"user_data":           userData,
			"enable_monitoring":   true,
			"enable_eip":          true,
			"root_volume_size":    10,
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "userdata",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Wait for instance to be ready
	instanceId := terraform.Output(t, terraformOptions, "instance_id")
	aws.WaitForInstanceRunning(t, instanceId, awsRegion)

	// Verify instance is running
	ec2Instance := aws.GetEc2InstanceById(t, instanceId, awsRegion)
	assert.Equal(t, "running", *ec2Instance.State.Name, "Instance should be running")

	// You could add SSH connectivity test here if you have the key pair
	// This would require setting up proper security groups and key pairs
}

// TestEC2MultipleInstances tests creating multiple EC2 instances
func TestEC2MultipleInstances(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-multi-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678"},
			"instance_count":      3,
			"enable_monitoring":   true,
			"root_volume_size":    10,
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "multiple",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify multiple instances were created
	instanceIds := terraform.OutputList(t, terraformOptions, "instance_ids")
	assert.Len(t, instanceIds, 3, "Should have 3 instances")

	// Verify all instances are running
	for i, instanceId := range instanceIds {
		ec2Instance := aws.GetEc2InstanceById(t, instanceId, awsRegion)
		assert.Equal(t, "running", *ec2Instance.State.Name, fmt.Sprintf("Instance %d should be running", i))
		assert.Equal(t, "t3.micro", *ec2Instance.InstanceType, fmt.Sprintf("Instance %d type should match", i))
	}
}

// TestEC2SecurityGroups tests EC2 security group configuration
func TestEC2SecurityGroups(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-sg-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678", "sg-87654321"},
			"enable_monitoring":   true,
			"create_security_group": true,
			"security_group_rules": []map[string]interface{}{
				{
					"type":        "ingress",
					"from_port":   80,
					"to_port":     80,
					"protocol":    "tcp",
					"cidr_blocks": []string{"0.0.0.0/0"},
				},
				{
					"type":        "ingress",
					"from_port":   22,
					"to_port":     22,
					"protocol":    "tcp",
					"cidr_blocks": []string{"10.0.0.0/16"},
				},
			},
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "security-groups",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify security group was created
	securityGroupId := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, securityGroupId, "Security group ID should not be empty")

	// Verify security group rules
	securityGroup := aws.GetSecurityGroupById(t, securityGroupId, awsRegion)
	assert.NotNil(t, securityGroup, "Security group should exist")
	
	// Check ingress rules
	assert.Len(t, securityGroup.IpPermissions, 2, "Should have 2 ingress rules")
	
	// Verify HTTP rule
	httpRule := findRuleByPort(securityGroup.IpPermissions, 80)
	assert.NotNil(t, httpRule, "HTTP rule should exist")
	assert.Equal(t, "tcp", *httpRule.IpProtocol, "HTTP rule should be TCP")
	
	// Verify SSH rule
	sshRule := findRuleByPort(securityGroup.IpPermissions, 22)
	assert.NotNil(t, sshRule, "SSH rule should exist")
	assert.Equal(t, "tcp", *sshRule.IpProtocol, "SSH rule should be TCP")
}

// TestEC2IAMRole tests EC2 instance with IAM role
func TestEC2IAMRole(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-iam-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678"},
			"enable_monitoring":   true,
			"create_iam_role":     true,
			"iam_role_policies": []string{
				"arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
				"arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
			},
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "iam-role",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify IAM role was created
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	instanceProfileArn := terraform.Output(t, terraformOptions, "instance_profile_arn")
	
	assert.NotEmpty(t, iamRoleArn, "IAM role ARN should not be empty")
	assert.NotEmpty(t, instanceProfileArn, "Instance profile ARN should not be empty")

	// Verify instance is associated with the IAM role
	instanceId := terraform.Output(t, terraformOptions, "instance_id")
	ec2Instance := aws.GetEc2InstanceById(t, instanceId, awsRegion)
	assert.NotNil(t, ec2Instance.IamInstanceProfile, "Instance should have IAM instance profile")
}

// TestEC2SpotInstance tests EC2 spot instance creation
func TestEC2SpotInstance(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-spot-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678"},
			"enable_monitoring":   true,
			"use_spot_instance":   true,
			"spot_price":          "0.01",
			"spot_type":           "one-time",
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "spot-instance",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify spot instance request was created
	spotInstanceRequestId := terraform.Output(t, terraformOptions, "spot_instance_request_id")
	assert.NotEmpty(t, spotInstanceRequestId, "Spot instance request ID should not be empty")

	// Wait for spot instance to be fulfilled
	maxRetries := 30
	timeBetweenRetries := 10 * time.Second
	
	retry.DoWithRetry(t, "Wait for spot instance", maxRetries, timeBetweenRetries, func() (string, error) {
		instanceId := terraform.Output(t, terraformOptions, "instance_id")
		if instanceId == "" {
			return "", fmt.Errorf("Spot instance not yet fulfilled")
		}
		
		ec2Instance := aws.GetEc2InstanceById(t, instanceId, awsRegion)
		if *ec2Instance.State.Name != "running" {
			return "", fmt.Errorf("Instance not yet running: %s", *ec2Instance.State.Name)
		}
		
		return "Spot instance is running", nil
	})
}

// Helper function to find security group rule by port
func findRuleByPort(rules []*ec2.IpPermission, port int64) *ec2.IpPermission {
	for _, rule := range rules {
		if *rule.FromPort == port && *rule.ToPort == port {
			return rule
		}
	}
	return nil
}

// TestEC2DataVolumes tests EC2 instance with additional EBS volumes
func TestEC2DataVolumes(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	instanceName := fmt.Sprintf("test-ec2-volumes-%s", uniqueId)
	awsRegion := "us-west-2"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/aws/ec2",
		Vars: map[string]interface{}{
			"instance_name":        instanceName,
			"instance_type":        "t3.micro",
			"ami_id":              "ami-0c02fb55956c7d316",
			"key_name":            "test-key",
			"subnet_id":           "subnet-12345678",
			"security_group_ids":  []string{"sg-12345678"},
			"enable_monitoring":   true,
			"additional_volumes": []map[string]interface{}{
				{
					"device_name": "/dev/sdf",
					"volume_size": 10,
					"volume_type": "gp3",
					"encrypted":   true,
				},
				{
					"device_name": "/dev/sdg",
					"volume_size": 20,
					"volume_type": "gp3",
					"encrypted":   true,
				},
			},
			"tags": map[string]string{
				"Environment": "test",
				"TestType":    "data-volumes",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify additional volumes were created
	instanceId := terraform.Output(t, terraformOptions, "instance_id")
	volumes := aws.GetEbsVolumesForInstance(t, instanceId, awsRegion)
	
	// Should have root volume + 2 additional volumes
	assert.Len(t, volumes, 3, "Should have 3 volumes total")

	// Verify additional volumes
	additionalVolumeIds := terraform.OutputList(t, terraformOptions, "additional_volume_ids")
	assert.Len(t, additionalVolumeIds, 2, "Should have 2 additional volumes")

	for _, volumeId := range additionalVolumeIds {
		volume := aws.GetEbsVolumeById(t, volumeId, awsRegion)
		assert.True(t, *volume.Encrypted, "Additional volume should be encrypted")
		assert.Equal(t, "gp3", *volume.VolumeType, "Additional volume should be gp3")
	}
}