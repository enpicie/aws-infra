# ------------------------------------------------------------
# WAF Web ACL — rate limiting for the ALB
#
# Threshold: 300 requests per 5-minute window (~60 req/min per IP).
# This is a safety margin below the start.gg API limit of 80 req/min,
# preventing any single IP from driving traffic at a rate that could
# approach that ceiling.
# ------------------------------------------------------------

resource "aws_wafv2_web_acl" "alb" {
  name  = "${var.name}-alb-rate-limit"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 300
        evaluation_window_sec = 300
        aggregate_key_type    = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-alb-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-alb-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
