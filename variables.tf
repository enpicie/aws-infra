variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zone names to deploy into (e.g. [\"us-east-2a\", \"us-east-2b\"])."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ. These host the ALB and NAT Gateway(s)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ. These host ECS Fargate tasks and VPC-attached Lambdas."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to provision NAT Gateway(s) for private subnet outbound internet access."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = <<-EOT
    When true, a single NAT Gateway is shared across all private subnets (cost-optimised for
    personal/dev accounts). When false, one NAT Gateway is provisioned per AZ for HA.
    Only relevant when enable_nat_gateway = true.
  EOT
  type        = bool
  default     = true
}

variable "enable_ecr_endpoints" {
  description = <<-EOT
    Create interface VPC endpoints for ECR (ecr.api + ecr.dkr). Required for ECS Fargate tasks
    running in private subnets to pull images without routing through a NAT Gateway.
  EOT
  type        = bool
  default     = true
}

variable "enable_cloudwatch_endpoint" {
  description = <<-EOT
    Create an interface VPC endpoint for CloudWatch Logs. Required for ECS Fargate tasks in private
    subnets to ship logs without routing through a NAT Gateway.
  EOT
  type        = bool
  default     = true
}


variable "tags" {
  description = "Additional tags to merge onto all resources."
  type        = map(string)
  default     = {}
}
