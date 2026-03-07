aws_region = "us-east-1"
name       = "personal"

cidr_block = "10.0.0.0/16"

azs = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

single_nat_gateway         = true
enable_nat_gateway         = true
enable_ecr_endpoints       = true
enable_cloudwatch_endpoint = true

tags = {
  Environment = "personal"
}
