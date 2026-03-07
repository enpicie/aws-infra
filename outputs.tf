output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

# ------------------------------------------------------------
# Subnets
# ------------------------------------------------------------

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ). Use these for your ALB."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (one per AZ). Use these for ECS Fargate and Lambdas."
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets."
  value       = aws_subnet.private[*].cidr_block
}

# ------------------------------------------------------------
# NAT Gateway
# ------------------------------------------------------------

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s). Empty when enable_nat_gateway = false."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Elastic IP addresses of the NAT Gateway(s). Useful for allowlisting in external services."
  value       = aws_eip.nat[*].public_ip
}

# ------------------------------------------------------------
# Route Tables
# ------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables (one per AZ)."
  value       = aws_route_table.private[*].id
}

# ------------------------------------------------------------
# VPC Endpoints
# ------------------------------------------------------------

output "s3_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "ecr_api_endpoint_id" {
  description = "ID of the ECR API interface endpoint. Empty when enable_ecr_endpoints = false."
  value       = length(aws_vpc_endpoint.ecr_api) > 0 ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "ecr_dkr_endpoint_id" {
  description = "ID of the ECR DKR interface endpoint. Empty when enable_ecr_endpoints = false."
  value       = length(aws_vpc_endpoint.ecr_dkr) > 0 ? aws_vpc_endpoint.ecr_dkr[0].id : null
}

output "cloudwatch_logs_endpoint_id" {
  description = "ID of the CloudWatch Logs interface endpoint. Empty when enable_cloudwatch_endpoint = false."
  value       = length(aws_vpc_endpoint.cloudwatch_logs) > 0 ? aws_vpc_endpoint.cloudwatch_logs[0].id : null
}

output "endpoint_security_group_id" {
  description = "ID of the security group attached to interface endpoints. Null when no interface endpoints are created."
  value       = length(aws_security_group.endpoints) > 0 ? aws_security_group.endpoints[0].id : null
}

# ------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------

output "ecs_cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

# ------------------------------------------------------------
# ALB
# ------------------------------------------------------------

output "alb_id" {
  description = "ID of the Application Load Balancer."
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Use this as the target for Route53 alias records in app repos."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB. Required for Route53 alias records in app repos."
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group. App repos should allow inbound traffic from this SG on their ECS task security groups."
  value       = aws_security_group.alb.id
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener. App repos attach listener rules to this to route traffic to their target groups."
  value       = aws_lb_listener.https.arn
}

# ------------------------------------------------------------
# DNS / ACM
# ------------------------------------------------------------

output "route53_zone_id" {
  description = "ID of the Route53 hosted zone."
  value       = aws_route53_zone.this.zone_id
}

output "route53_zone_name" {
  description = "Name of the Route53 hosted zone."
  value       = aws_route53_zone.this.name
}

output "acm_certificate_arn" {
  description = "ARN of the wildcard ACM certificate. Can be attached to additional listeners or CloudFront distributions."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
