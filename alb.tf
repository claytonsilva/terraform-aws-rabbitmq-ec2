# Create a new network load balancer internal
resource "aws_lb" "this" {
  name                             = local.lb_name
  internal                         = var.is_lb_internal
  load_balancer_type               = "network"
  subnets                          = var.alb_subnet_ids
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false
  security_groups                  = concat(var.additional_sg_lb_ids, aws_security_group.lb.id)

  tags = merge(var.default_tags, {
    Account = local.account_alias
    Name    = local.lb_name
  })
}

# Create Target groups
resource "aws_lb_target_group" "this" {
  for_each = local.rabbit_service_ports
  name     = "tg-${local.lb_name}-${each.key}"
  port     = each.value.port
  protocol = "TCP"
  vpc_id   = local.vpc_id
  health_check {
    enabled  = true
    protocol = "TCP"
  }
}


# Create Listeners
resource "aws_alb_listener" "this" {
  for_each          = local.nlb_listener_ports
  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.secure ? "TLS" : "TCP"

  certificate_arn = each.value.certificate_arn
  ssl_policy      = each.value.ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.service_port].arn
  }
  depends_on = [aws_lb_target_group.this]
}

resource "aws_route53_record" "internal_cname" {
  provider = aws.route53_account
  zone_id  = data.aws_route53_zone.hosted_zone.id
  name     = "${var.name}.${var.domain_name}"
  type     = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
