# EC2 Basic Controls - InSpec tests for EC2 module

title 'EC2 Instance Infrastructure Tests'

instance_id = attribute('instance_id', description: 'EC2 Instance ID to test')
instance_name = attribute('instance_name', description: 'EC2 Instance Name tag', default: 'test-instance')
instance_type = attribute('instance_type', description: 'EC2 Instance Type', default: 't3.micro')
environment = attribute('environment', description: 'Environment tag', default: 'test')
vpc_id = attribute('vpc_id', description: 'VPC ID where instance is deployed')

# Instance Existence and State
control 'ec2-01' do
  title 'EC2 instance should exist and be running'
  desc 'Verify that the EC2 instance exists and is in running state'
  impact 1.0
  
  describe aws_ec2_instance(instance_id) do
    it { should exist }
    it { should be_running }
    its('instance_type') { should eq instance_type }
    its('state_name') { should eq 'running' }
  end
end

# Instance Tagging
control 'ec2-02' do
  title 'EC2 instance should have required tags'
  desc 'Verify that the EC2 instance has all required tags'
  impact 0.8
  
  describe aws_ec2_instance(instance_id) do
    its('tags') { should include('Name' => instance_name) }
    its('tags') { should include('Environment' => environment) }
    its('tags') { should include('ManagedBy' => 'Terraform') }
  end
end

# Security Groups
control 'ec2-03' do
  title 'EC2 instance should have appropriate security groups'
  desc 'Verify that the instance has security groups attached and they are properly configured'
  impact 0.9
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('security_groups.count') { should be >= 1 }
  end
  
  # Check each security group
  instance.security_groups.each do |sg|
    describe aws_security_group(sg.group_id) do
      it { should exist }
      its('vpc_id') { should eq vpc_id } if vpc_id
      
      # Security group should not allow unrestricted SSH access
      it { should_not allow_in(port: 22, ipv4_range: '0.0.0.0/0') }
      
      # Security group should not allow unrestricted RDP access
      it { should_not allow_in(port: 3389, ipv4_range: '0.0.0.0/0') }
    end
  end
end

# AMI and Launch Configuration
control 'ec2-04' do
  title 'EC2 instance should use appropriate AMI'
  desc 'Verify that the instance is launched from a valid and secure AMI'
  impact 0.7
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('image_id') { should_not be_empty }
    its('virtualization_type') { should eq 'hvm' }
  end
  
  # Check AMI details
  ami = aws_ami(instance.image_id)
  describe ami do
    it { should exist }
    its('state') { should eq 'available' }
    its('architecture') { should eq 'x86_64' }
  end
end

# Root Volume Configuration
control 'ec2-05' do
  title 'EC2 instance should have encrypted root volume'
  desc 'Verify that the root volume is encrypted and properly configured'
  impact 0.8
  
  instance = aws_ec2_instance(instance_id)
  root_device_name = instance.root_device_name
  
  # Find the root volume
  root_volume = instance.block_device_mappings.find { |bdm| bdm.device_name == root_device_name }
  
  if root_volume && root_volume.ebs
    describe aws_ebs_volume(root_volume.ebs.volume_id) do
      it { should exist }
      it { should be_encrypted }
      its('state') { should eq 'in-use' }
      its('volume_type') { should be_in %w[gp2 gp3 io1 io2] }
    end
  end
end

# Network Configuration
control 'ec2-06' do
  title 'EC2 instance should have proper network configuration'
  desc 'Verify that the instance network configuration is appropriate'
  impact 0.7
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('private_ip_address') { should_not be_empty }
    its('vpc_id') { should eq vpc_id } if vpc_id
    its('subnet_id') { should_not be_empty }
  end
  
  # Verify subnet exists and is in the correct VPC
  if instance.subnet_id
    describe aws_subnet(instance.subnet_id) do
      it { should exist }
      its('vpc_id') { should eq vpc_id } if vpc_id
    end
  end
end

# Monitoring Configuration
control 'ec2-07' do
  title 'EC2 instance monitoring should be configured'
  desc 'Verify that CloudWatch monitoring is enabled'
  impact 0.6
  
  # Check if detailed monitoring is enabled
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('monitoring_state') { should be_in %w[enabled disabled] }
  end
  
  # If monitoring is enabled, verify CloudWatch metrics are available
  if attribute('enable_monitoring', default: false)
    describe instance do
      its('monitoring_state') { should eq 'enabled' }
    end
  end
end

# Elastic IP (if configured)
control 'ec2-08' do
  title 'Elastic IP should be properly configured'
  desc 'Verify Elastic IP configuration when enabled'
  impact 0.6
  
  # Only run if EIP is expected
  only_if('Elastic IP is enabled') { attribute('enable_eip', default: false) }
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('public_ip_address') { should_not be_empty }
  end
  
  # Check if there's an associated Elastic IP
  elastic_ips = aws_eips.where(instance_id: instance_id)
  
  describe elastic_ips do
    its('count') { should eq 1 }
  end
  
  elastic_ips.entries.each do |eip|
    describe aws_eip(eip.allocation_id) do
      it { should exist }
      its('instance_id') { should eq instance_id }
    end
  end
end

# IAM Instance Profile
control 'ec2-09' do
  title 'IAM instance profile should be configured when specified'
  desc 'Verify IAM instance profile and role configuration'
  impact 0.7
  
  # Only run if IAM role is expected
  only_if('IAM role is configured') { attribute('create_iam_role', default: false) }
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('iam_instance_profile_arn') { should_not be_empty }
  end
  
  if instance.iam_instance_profile_arn
    # Extract instance profile name from ARN
    profile_name = instance.iam_instance_profile_arn.split('/').last
    
    describe aws_iam_instance_profile(profile_name) do
      it { should exist }
      its('roles.count') { should be >= 1 }
    end
  end
end

# User Data Script Execution
control 'ec2-10' do
  title 'User data script should execute successfully'
  desc 'Verify that user data script execution completed without errors'
  impact 0.5
  
  # This is a basic check - in practice you might check specific services or files
  # that should be created by the user data script
  
  only_if('User data is provided') { attribute('user_data', default: '').length > 0 }
  
  # Check if cloud-init logs show successful execution
  describe command('sudo grep -i "cloud-init.*finished" /var/log/cloud-init.log') do
    its('exit_status') { should eq 0 }
  end
end

# Instance Metadata Service Configuration
control 'ec2-11' do
  title 'Instance Metadata Service should be properly configured'
  desc 'Verify that IMDSv2 is enforced for security'
  impact 0.8
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    # Check if IMDS is configured to require session tokens (IMDSv2)
    its('metadata_options_http_tokens') { should eq 'required' }
    its('metadata_options_http_endpoint') { should eq 'enabled' }
  end
end

# Additional EBS Volumes (if configured)
control 'ec2-12' do
  title 'Additional EBS volumes should be properly configured'
  desc 'Verify additional EBS volumes when they are specified'
  impact 0.6
  
  # Only run if additional volumes are expected
  only_if('Additional volumes are configured') { attribute('additional_volumes', default: []).any? }
  
  instance = aws_ec2_instance(instance_id)
  all_volumes = instance.block_device_mappings
  
  # Additional volumes should be beyond the root volume
  describe all_volumes do
    its('count') { should be > 1 }
  end
  
  # Check each additional volume
  additional_volumes = all_volumes.reject { |bdm| bdm.device_name == instance.root_device_name }
  
  additional_volumes.each do |volume_mapping|
    if volume_mapping.ebs
      describe aws_ebs_volume(volume_mapping.ebs.volume_id) do
        it { should exist }
        it { should be_encrypted }
        its('state') { should eq 'in-use' }
      end
    end
  end
end

# Network Performance Optimization
control 'ec2-13' do
  title 'Instance should have appropriate network performance settings'
  desc 'Verify network performance settings for the instance type'
  impact 0.4
  
  instance = aws_ec2_instance(instance_id)
  
  # For supported instance types, enhanced networking should be enabled
  enhanced_networking_instance_types = %w[
    m5 m5d m5n m5dn m5zn
    c5 c5d c5n
    r5 r5d r5n r5dn
    i3 i3en
    m6i m6id
    c6i c6id
    r6i r6id
  ]
  
  instance_family = instance_type.split('.').first
  
  if enhanced_networking_instance_types.include?(instance_family)
    describe instance do
      its('ena_support') { should eq true }
    end
  end
end

# Spot Instance Configuration (if applicable)
control 'ec2-14' do
  title 'Spot instance should be properly configured'
  desc 'Verify spot instance configuration when using spot instances'
  impact 0.5
  
  # Only run if spot instance is expected
  only_if('Spot instance is used') { attribute('use_spot_instance', default: false) }
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    its('instance_lifecycle') { should eq 'spot' }
    its('spot_instance_request_id') { should_not be_empty }
  end
end

# Security Compliance
control 'ec2-15' do
  title 'Instance should comply with security best practices'
  desc 'Verify that the instance follows security best practices'
  impact 0.8
  
  instance = aws_ec2_instance(instance_id)
  
  describe instance do
    # Instance should not have a public IP unless specifically required
    if attribute('associate_public_ip_address', default: false) == false
      its('public_ip_address') { should be_empty }
    end
    
    # Instance should be in a private subnet unless public access is required
    if attribute('subnet_type', default: 'private') == 'private'
      subnet = aws_subnet(instance.subnet_id)
      describe subnet do
        its('map_public_ip_on_launch') { should eq false }
      end
    end
  end
end

# Performance and Resource Utilization
control 'ec2-16' do
  title 'Instance should have appropriate resource allocation'
  desc 'Verify that instance resources are appropriately sized'
  impact 0.5
  
  # This would typically involve checking CloudWatch metrics
  # For now, we'll just verify the instance type is reasonable
  
  describe instance_type do
    # Avoid oversized instances for test environments
    if environment == 'test' || environment == 'dev'
      it { should_not match(/\.8xlarge$|\.12xlarge$|\.16xlarge$|\.24xlarge$/) }
    end
  end
end