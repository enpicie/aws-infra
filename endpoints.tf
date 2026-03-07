data "aws_region" "current" {}

# ------------------------------------------------------------
# S3 Gateway Endpoint  (free; bypasses NAT for S3 traffic)
# ------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  # Associate with all route tables so both public and private subnets benefit.
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = merge(local.common_tags, {
    Name = "${var.name}-s3-endpoint"
  })
}

# ------------------------------------------------------------
# Security Group for Interface Endpoints
# Only allows HTTPS from within the VPC CIDR.
# ------------------------------------------------------------

resource "aws_security_group" "endpoints" {
  count = var.enable_ecr_endpoints || var.enable_cloudwatch_endpoint ? 1 : 0

  name        = "${var.name}-vpc-endpoints"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc-endpoints"
  })
}

# ------------------------------------------------------------
# ECR Interface Endpoints
# Both are required for Fargate to pull images from ECR.
# ecr.api  - authentication & image manifest calls
# ecr.dkr  - actual layer/image data transfer
# ------------------------------------------------------------

resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_ecr_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-ecr-api-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_ecr_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-ecr-dkr-endpoint"
  })
}

# ------------------------------------------------------------
# CloudWatch Logs Interface Endpoint
# Required for ECS Fargate tasks in private subnets to ship
# logs to CloudWatch without going through the NAT Gateway.
# ------------------------------------------------------------

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  count = var.enable_cloudwatch_endpoint ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-cloudwatch-logs-endpoint"
  })
}
