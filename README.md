# aws-infra

Terraform configuration for shared AWS platform infrastructure. Provisions the foundational layer that application repos deploy on top of — VPC networking, ECS cluster, and ALB. State is stored in S3 with DynamoDB locking.

Route53 hosted zones and ACM certificates are managed per-app in their own repos, not here.

## Core infrastructure

| Entity | What it is |
| --- | --- |
| **VPC** | A single VPC with public and private subnets spread across two AZs. Public subnets host the ALB and NAT Gateway. Private subnets host ECS Fargate tasks and are not reachable from the internet. |
| **NAT Gateway** | Deployed in a public subnet (single, shared across AZs by default). Gives private subnets outbound internet access. |
| **VPC Endpoints** | S3 gateway endpoint (free, attached to all route tables) plus optional interface endpoints for ECR and CloudWatch Logs. Keeps that traffic on the AWS private backbone and off the NAT Gateway. |
| **ECS Cluster** | A shared Fargate cluster with Container Insights enabled. Registers both `FARGATE` and `FARGATE_SPOT` capacity providers — app repos choose the strategy per service. |
| **Application Load Balancer** | A single internet-facing ALB in the public subnets. No listeners are provisioned here; app repos attach their own listeners, listener rules, and ACM certificates. |

## File reference

### [`main.tf`](main.tf) — VPC networking

The core network layer. Everything else lives inside this VPC.

| Resource                                 | Description                                                                                                                                                                |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `aws_vpc.this`                           | The VPC. DNS support and hostnames enabled — required for VPC endpoint private DNS resolution.                                                                             |
| `aws_internet_gateway.this`              | Attached to the VPC; provides outbound internet access for public subnets.                                                                                                 |
| `aws_subnet.public[*]`                   | One public subnet per AZ. Hosts the ALB and NAT Gateway(s). Resources here get public IPs by default.                                                                     |
| `aws_subnet.private[*]`                  | One private subnet per AZ. Hosts ECS Fargate tasks. Not reachable from the internet.                                                                                       |
| `aws_route_table.public`                 | Single route table for all public subnets. Default route (`0.0.0.0/0`) points to the Internet Gateway.                                                                    |
| `aws_route_table.private[*]`             | One route table per private subnet. Allows each AZ to route through its own NAT Gateway when `single_nat_gateway = false`.                                                |
| `aws_route_table_association.public[*]`  | Associates each public subnet with the public route table.                                                                                                                 |
| `aws_route_table_association.private[*]` | Associates each private subnet with its corresponding private route table.                                                                                                 |
| `aws_eip.nat[*]`                         | Elastic IP(s) for the NAT Gateway(s). Count matches `local.nat_count`.                                                                                                    |
| `aws_nat_gateway.this[*]`                | Placed in public subnets; gives private subnets outbound internet access without exposing them inbound. Count is 1 when `single_nat_gateway = true`, one per AZ otherwise. |
| `aws_route.private_nat[*]`               | Default route in each private route table pointing to the NAT Gateway.                                                                                                     |

---

### [`endpoints.tf`](endpoints.tf) — VPC endpoints

Keeps traffic to AWS services on the AWS private backbone instead of routing through the NAT Gateway. Reduces cost and latency, and removes a failure point for ECS tasks that need to reach ECR or CloudWatch.

| Resource                              | Type      | Description                                                                                                                  |
| ------------------------------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `aws_vpc_endpoint.s3`                 | Gateway   | Free. Routes S3 traffic directly from both public and private subnets without hitting NAT. Associated with all route tables. |
| `aws_security_group.endpoints[0]`     | —         | Allows inbound HTTPS (443) from within the VPC CIDR. Attached to all interface endpoints.                                   |
| `aws_vpc_endpoint.ecr_api[0]`         | Interface | Handles ECR authentication and image manifest calls. Required for Fargate to pull images from ECR in a private subnet.       |
| `aws_vpc_endpoint.ecr_dkr[0]`         | Interface | Handles ECR image layer transfers. Required alongside `ecr.api` for full image pull functionality.                           |
| `aws_vpc_endpoint.cloudwatch_logs[0]` | Interface | Allows ECS tasks in private subnets to ship logs to CloudWatch without going through NAT.                                    |

---

### [`cluster.tf`](cluster.tf) — ECS cluster

The shared compute cluster. All ECS services across app repos deploy into this cluster.

| Resource                                  | Description                                                                                                                                                              |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `aws_ecs_cluster.this`                    | The ECS cluster. Container Insights enabled for CloudWatch metrics and logging.                                                                                          |
| `aws_ecs_cluster_capacity_providers.this` | Registers FARGATE and FARGATE_SPOT as capacity providers. Default strategy is FARGATE. App repos can override to FARGATE_SPOT for non-critical workloads to reduce cost. |

---

### [`alb.tf`](alb.tf) — Application Load Balancer

The shared public entry point for all services. App repos attach their own listeners, listener rules, and ACM certificates — they do not create their own ALBs.

| Resource                 | Description                                                                                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `aws_security_group.alb` | Allows inbound HTTP (80) and HTTPS (443) from the internet. Allows all outbound to reach ECS tasks. App repos reference this SG ID to allow traffic into their ECS tasks. |
| `aws_lb.this`            | Internet-facing ALB placed in public subnets. No listeners are provisioned here — app repos own their listeners and listener rules.                                     |

---

### [`providers.tf`](providers.tf) — Provider and backend configuration

| Block                              | Description                                                                                                                                     |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `terraform.required_version`       | Requires Terraform >= 1.5.0.                                                                                                                    |
| `terraform.required_providers.aws` | AWS provider >= 5.0.                                                                                                                            |
| `terraform.backend "s3"`           | Remote state stored in S3 with DynamoDB locking. Must be bootstrapped manually before first `terraform init`.                                   |
| `provider "aws"`                   | Configures the AWS provider with `var.aws_region`. Applies `ManagedBy = "terraform"` and `Repo = "aws-infra"` as default tags on all resources. |

---

### [`variables.tf`](variables.tf) — Input variables

Declares all input variables. See the [Variables](#variables) section for descriptions and defaults.

### [`outputs.tf`](outputs.tf) — Output values

Exposes resource IDs and ARNs for consumption by app repos via `terraform_remote_state`. See the [Consuming outputs in app repos](#consuming-outputs-in-app-repos) section.

## Prerequisites

Before running `terraform apply` for the first time:

1. **S3 state bucket and DynamoDB lock table** — create once manually:

   ```bash
   aws s3api create-bucket --bucket <YOUR_BUCKET> --region us-east-2
   aws s3api put-bucket-versioning --bucket <YOUR_BUCKET> \
     --versioning-configuration Status=Enabled
   aws dynamodb create-table --table-name terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST --region us-east-2
   ```

2. **HCP Terraform workspace admin IAM role** — create manually and attach to the HCP workspace variable set. This workspace manages foundational infra so it requires broad AWS permissions.

## Deployment

Deployments are triggered via GitHub Actions (`.github/workflows/vpc-deploy.yml`) on push to `main` for any `.tf` or `.tfvars` changes. Runs are executed via HCP Terraform.

## Consuming outputs in app repos

App repos reference this workspace's outputs via Terraform remote state:

```hcl
data "terraform_remote_state" "infra" {
  backend = "remote"
  config = {
    organization = "<your-hcp-org>"
    workspaces = { name = "aws-infra-vpc" }
  }
}
```

Key outputs available:

| Output               | Used for                                              |
| -------------------- | ----------------------------------------------------- |
| `vpc_id`             | Attaching resources to the VPC                        |
| `private_subnet_ids` | ECS service network configuration                     |
| `public_subnet_ids`  | ALB listener and target group placement               |
| `ecs_cluster_arn`    | ECS service `cluster` reference                       |
| `alb_arn`            | Attaching listeners and listener rules                |
| `alb_dns_name`       | Creating Route53 alias records pointing to the ALB    |
| `alb_zone_id`        | Required alongside `alb_dns_name` for alias records   |
| `alb_security_group_id` | Allowing ALB traffic into ECS task security groups |

## Variables

| Variable                     | Required | Default       | Description                               |
| ---------------------------- | -------- | ------------- | ----------------------------------------- |
| `name`                       | yes      | —             | Name prefix for all resources             |
| `aws_region`                 | no       | `us-east-2`   | AWS region                                |
| `cidr_block`                 | no       | `10.0.0.0/16` | VPC CIDR block                            |
| `azs`                        | yes      | —             | List of AZ names                          |
| `public_subnet_cidrs`        | yes      | —             | One CIDR per AZ for public subnets        |
| `private_subnet_cidrs`       | yes      | —             | One CIDR per AZ for private subnets       |
| `enable_nat_gateway`         | no       | `true`        | Provision NAT Gateway(s)                  |
| `single_nat_gateway`         | no       | `true`        | Share one NAT Gateway across all AZs      |
| `enable_ecr_endpoints`       | no       | `true`        | Create ECR VPC endpoints                  |
| `enable_cloudwatch_endpoint` | no       | `true`        | Create CloudWatch Logs VPC endpoint       |
| `tags`                       | no       | `{}`          | Additional tags merged onto all resources |
