# Create a new network load balancer internal
#tfsec:ignore:AWS005
resource "aws_lb" "nlb_internal" {
  name = local.lb_name_internal
  # public because we need to connect with managed rabbitmq broker
  # https://docs.aws.amazon.com/amazon-mq/latest/developer-guide/rabbitmq-basic-elements-plugins.html#rabbitmq-federation-plugin
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = local.all_private_subnets
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false
  security_groups                  = [aws_security_group.nlb_internal.id]

  tags = merge(var.default_tags, {
    Account = data.aws_iam_account_alias.this.account_alias
    Name    = local.lb_name_internal
  })
}

# Create Listeners
resource "aws_lb_listener" "listener_internal_amqp" {
  load_balancer_arn = aws_lb.nlb_internal.arn
  port              = "5672"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_internal_amqp.arn
  }
}

resource "aws_lb_listener" "listener_internal_amqps" {
  load_balancer_arn = aws_lb.nlb_internal.arn
  port              = "5671"
  protocol          = "TLS"

  certificate_arn = var.certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_internal_amqp.arn
  }
}

resource "aws_lb_listener" "listener_internal_http" {
  load_balancer_arn = aws_lb.nlb_internal.arn
  port              = "443"
  protocol          = "TLS"

  certificate_arn = var.certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_internal_http.arn
  }
}

resource "aws_lb_listener" "listener_internal_consul" {
  load_balancer_arn = aws_lb.nlb_internal.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_internal_consul_http.arn
  }
}

# Create Target Groups
resource "aws_lb_target_group" "tg_internal_http" {
  name     = "tg-rabbitmq-internal-http"
  port     = 15672
  protocol = "TCP"
  vpc_id   = local.vpc_id
  health_check {
    enabled  = true
    protocol = "TCP"
  }
}

resource "aws_lb_target_group" "tg_internal_consul_http" {
  name     = "tg-rabbitmq-internal-consul-http"
  port     = 8500
  protocol = "TCP"
  vpc_id   = local.vpc_id
  health_check {
    enabled  = true
    protocol = "TCP"
  }
}

resource "aws_lb_target_group" "tg_internal_amqp" {
  name     = "tg-rabbitmq-internal-amqp"
  port     = 5672
  protocol = "TCP"
  vpc_id   = local.vpc_id
  health_check {
    enabled  = true
    protocol = "TCP"
  }
}

resource "aws_route53_record" "nlb_internal_cname" {
  provider = aws.route53_account
  zone_id  = data.aws_route53_zone.hosted_zone.id
  name     = "rabbitmq.${var.domain_name}"
  type     = "A"

  alias {
    name                   = aws_lb.nlb_internal.dns_name
    zone_id                = aws_lb.nlb_internal.zone_id
    evaluate_target_health = true
  }
}
