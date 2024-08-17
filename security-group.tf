resource "aws_security_group" "lb" {
  name        = "${var.name}-nlb-internal"
  description = "Security Group RabbitMQ Cluster (nlb internal)"
  vpc_id      = local.vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    description = "Enable All Internet Traffic"
  }

  tags = merge(var.default_tags, {
    Account = local.account_alias
    Name    = var.name
  })

  lifecycle {
    ignore_changes = [ingress]
  }
}


resource "aws_security_group" "main" {
  name        = var.name
  description = "Security Group RabbitMQ Cluster"
  vpc_id      = local.vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    description = "Enable All Internet Traffic"
  }

  tags = merge(var.default_tags, {
    Account = local.account_alias
    Name    = var.name
  })

  lifecycle {
    ignore_changes = [ingress]
  }
}

### internal comm between nodes from cluster
resource "aws_security_group_rule" "enable_internal_comm" {
  type              = "ingress"
  security_group_id = aws_security_group.main.id
  self              = true
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  description       = "Allow inter node traffic"
}

### internal comm between nlb and ec2
resource "aws_security_group_rule" "enable_ports_to_internal_nlb" {
  for_each                 = local.rabbit_service_ports
  type                     = "ingress"
  security_group_id        = aws_security_group.main.id
  source_security_group_id = aws_security_group.lb.id
  protocol                 = "tcp"
  from_port                = each.value.port
  to_port                  = each.value.port
  description              = "Allow traffic to rabbitmq - from inner VPC to internal nlb - ${each.key}"
}


### internal comm between nlb and local vpc
resource "aws_security_group_rule" "enable_ports_vpc" {
  for_each          = local.nlb_listener_ports
  type              = "ingress"
  security_group_id = aws_security_group.lb.id
  cidr_blocks       = [local.vpc_cidr]
  protocol          = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "Allow traffic to rabbitmq - from inner VPC - ${each.key}"
}

#### security group for efs mount
resource "aws_security_group" "efs" {
  name        = "${var.name}-efs"
  description = "Security Group EFS File system for rabbit cluster"
  vpc_id      = local.vpc_id

  tags = merge(var.default_tags, {
    Account = local.account_alias
    Name    = "${var.name}-efs"
  })
}


resource "aws_security_group_rule" "enable_comm_from_rabbit_cluster" {
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.main.id
  protocol                 = "TCP"
  from_port                = 2049 # efs mount port
  to_port                  = 2049 # efs mount port
  description              = "Allow traffic to rabbitmq instances"
}
