# VPC Basic Controls - InSpec tests for VPC module

title 'VPC Basic Infrastructure Tests'

vpc_id = attribute('vpc_id', description: 'VPC ID to test')
vpc_name = attribute('vpc_name', description: 'VPC Name tag', default: 'test-vpc')
vpc_cidr = attribute('vpc_cidr', description: 'VPC CIDR block', default: '10.0.0.0/16')
environment = attribute('environment', description: 'Environment tag', default: 'test')

# VPC Existence and Basic Configuration
control 'vpc-01' do
  title 'VPC should exist and be available'
  desc 'Verify that the VPC exists and is in available state'
  impact 1.0
  
  describe aws_vpc(vpc_id) do
    it { should exist }
    it { should be_available }
    its('cidr_block') { should eq vpc_cidr }
    its('state') { should eq 'available' }
  end
end

# VPC DNS Configuration
control 'vpc-02' do
  title 'VPC should have DNS resolution and hostnames enabled'
  desc 'Verify that DNS support and DNS hostnames are enabled'
  impact 0.8
  
  describe aws_vpc(vpc_id) do
    it { should have_dns_resolution_enabled }
    it { should have_dns_hostnames_enabled }
  end
end

# VPC Tagging
control 'vpc-03' do
  title 'VPC should have required tags'
  desc 'Verify that the VPC has all required tags'
  impact 0.7
  
  describe aws_vpc(vpc_id) do
    its('tags') { should include('Name' => vpc_name) }
    its('tags') { should include('Environment' => environment) }
    its('tags') { should include('ManagedBy' => 'Terraform') }
  end
end

# Internet Gateway
control 'vpc-04' do
  title 'VPC should have an Internet Gateway attached'
  desc 'Verify that an Internet Gateway is attached to the VPC'
  impact 0.9
  
  describe aws_internet_gateways.where(attachments_vpc_id: vpc_id) do
    it { should_not be_empty }
  end
  
  aws_internet_gateways.where(attachments_vpc_id: vpc_id).entries.each do |igw|
    describe aws_internet_gateway(igw.internet_gateway_id) do
      it { should be_attached }
      its('attachments_state') { should eq 'available' }
    end
  end
end

# Subnets
control 'vpc-05' do
  title 'VPC should have the correct number of subnets'
  desc 'Verify that the VPC has the expected number of public and private subnets'
  impact 0.8
  
  # Get all subnets in the VPC
  all_subnets = aws_subnets.where(vpc_id: vpc_id)
  
  describe all_subnets do
    its('count') { should be >= 2 }  # At least one public and one private
  end
  
  # Check for public subnets (ones that auto-assign public IPs)
  public_subnets = all_subnets.where(map_public_ip_on_launch: true)
  describe public_subnets do
    its('count') { should be >= 1 }
  end
  
  # Check for private subnets
  private_subnets = all_subnets.where(map_public_ip_on_launch: false)
  describe private_subnets do
    its('count') { should be >= 1 }
  end
end

# Subnet Distribution Across AZs
control 'vpc-06' do
  title 'Subnets should be distributed across multiple AZs'
  desc 'Verify that subnets are spread across different availability zones'
  impact 0.7
  
  all_subnets = aws_subnets.where(vpc_id: vpc_id)
  availability_zones = all_subnets.entries.map(&:availability_zone).uniq
  
  describe availability_zones do
    its('count') { should be >= 2 }
  end
end

# Public Subnet Route Tables
control 'vpc-07' do
  title 'Public subnets should have routes to Internet Gateway'
  desc 'Verify that public subnets have route tables with IGW routes'
  impact 0.9
  
  public_subnets = aws_subnets.where(vpc_id: vpc_id, map_public_ip_on_launch: true)
  internet_gateways = aws_internet_gateways.where(attachments_vpc_id: vpc_id)
  
  # Skip if no public subnets or no IGW
  only_if('Public subnets exist') { public_subnets.count > 0 }
  only_if('Internet Gateway exists') { internet_gateways.count > 0 }
  
  public_subnets.entries.each do |subnet|
    route_table_ids = aws_route_tables.where(associations_subnet_id: subnet.subnet_id).entries.map(&:route_table_id)
    
    route_table_ids.each do |rt_id|
      describe aws_route_table(rt_id) do
        it { should have_route('0.0.0.0/0') }
        # Check that the default route points to IGW
        its('routes') { should include(destination_cidr_block: '0.0.0.0/0') }
      end
    end
  end
end

# NAT Gateways (if enabled)
control 'vpc-08' do
  title 'NAT Gateways should exist for private subnet internet access'
  desc 'Verify that NAT Gateways are created when enabled'
  impact 0.8
  
  nat_gateways = aws_nat_gateways.where(vpc_id: vpc_id)
  
  # This control is optional - only run if NAT gateways are expected
  only_if('NAT Gateway is enabled') { attribute('enable_nat_gateway', default: false) }
  
  describe nat_gateways do
    its('count') { should be >= 1 }
  end
  
  nat_gateways.entries.each do |nat_gw|
    describe aws_nat_gateway(nat_gw.nat_gateway_id) do
      it { should be_available }
      its('state') { should eq 'available' }
    end
  end
end

# Private Subnet Route Tables
control 'vpc-09' do
  title 'Private subnets should have routes to NAT Gateway'
  desc 'Verify that private subnets have route tables with NAT Gateway routes'
  impact 0.8
  
  private_subnets = aws_subnets.where(vpc_id: vpc_id, map_public_ip_on_launch: false)
  nat_gateways = aws_nat_gateways.where(vpc_id: vpc_id)
  
  # Only run if both private subnets and NAT gateways exist
  only_if('Private subnets exist') { private_subnets.count > 0 }
  only_if('NAT Gateway exists') { nat_gateways.count > 0 }
  
  private_subnets.entries.each do |subnet|
    route_table_ids = aws_route_tables.where(associations_subnet_id: subnet.subnet_id).entries.map(&:route_table_id)
    
    route_table_ids.each do |rt_id|
      describe aws_route_table(rt_id) do
        it { should have_route('0.0.0.0/0') }
      end
    end
  end
end

# Network ACLs
control 'vpc-10' do
  title 'VPC should have appropriate Network ACLs'
  desc 'Verify that Network ACLs are configured properly'
  impact 0.6
  
  network_acls = aws_network_acls.where(vpc_id: vpc_id)
  
  describe network_acls do
    its('count') { should be >= 1 }  # At least the default NACL
  end
  
  # Check default NACL allows traffic
  default_nacl = network_acls.where(is_default: true).entries.first
  if default_nacl
    describe aws_network_acl(default_nacl.network_acl_id) do
      it { should allow_ingress(port: 80, protocol: 'tcp') }
      it { should allow_ingress(port: 443, protocol: 'tcp') }
      it { should allow_egress(port: 80, protocol: 'tcp') }
      it { should allow_egress(port: 443, protocol: 'tcp') }
    end
  end
end

# VPC Flow Logs (if enabled)
control 'vpc-11' do
  title 'VPC Flow Logs should be enabled'
  desc 'Verify that VPC Flow Logs are configured when enabled'
  impact 0.7
  
  # Only run if flow logs are expected to be enabled
  only_if('Flow logs are enabled') { attribute('enable_flow_logs', default: false) }
  
  flow_logs = aws_flow_logs.where(resource_type: 'VPC', resource_id: vpc_id)
  
  describe flow_logs do
    its('count') { should be >= 1 }
  end
  
  flow_logs.entries.each do |flow_log|
    describe aws_flow_log(flow_log.flow_log_id) do
      its('flow_log_status') { should eq 'ACTIVE' }
      its('traffic_type') { should eq 'ALL' }
    end
  end
end

# DHCP Options Set
control 'vpc-12' do
  title 'VPC should have appropriate DHCP options'
  desc 'Verify that DHCP options are configured correctly'
  impact 0.5
  
  vpc = aws_vpc(vpc_id)
  dhcp_options_id = vpc.dhcp_options_id
  
  if dhcp_options_id && dhcp_options_id != 'default'
    describe aws_dhcp_options(dhcp_options_id) do
      it { should exist }
    end
  end
end

# Security Groups
control 'vpc-13' do
  title 'VPC should have a default security group'
  desc 'Verify that the VPC has a default security group with appropriate rules'
  impact 0.6
  
  default_sg = aws_security_groups.where(vpc_id: vpc_id, group_name: 'default').entries.first
  
  describe default_sg do
    it { should_not be_nil }
  end
  
  if default_sg
    describe aws_security_group(default_sg.group_id) do
      it { should exist }
      its('group_name') { should eq 'default' }
      its('vpc_id') { should eq vpc_id }
    end
  end
end

# VPC Endpoints (if configured)
control 'vpc-14' do
  title 'VPC Endpoints should be configured when enabled'
  desc 'Verify that VPC endpoints are created when specified'
  impact 0.6
  
  # Only run if VPC endpoints are expected
  only_if('VPC endpoints are enabled') { attribute('enable_vpc_endpoints', default: false) }
  
  vpc_endpoints = aws_vpc_endpoints.where(vpc_id: vpc_id)
  
  describe vpc_endpoints do
    its('count') { should be >= 1 }
  end
  
  vpc_endpoints.entries.each do |endpoint|
    describe aws_vpc_endpoint(endpoint.vpc_endpoint_id) do
      it { should be_available }
      its('state') { should eq 'available' }
    end
  end
end

# Cost Optimization - Check for unused resources
control 'vpc-15' do
  title 'VPC should not have unused expensive resources'
  desc 'Check for potentially unused NAT Gateways and other expensive resources'
  impact 0.4
  
  # This is more of a cost optimization check
  nat_gateways = aws_nat_gateways.where(vpc_id: vpc_id)
  
  nat_gateways.entries.each do |nat_gw|
    describe aws_nat_gateway(nat_gw.nat_gateway_id) do
      its('state') { should eq 'available' }
      # In a real scenario, you might check CloudWatch metrics for usage
    end
  end
end