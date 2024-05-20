resource "aws_launch_template" "rabbit_per_az" {
  for_each               = local.az_with_context
  name                   = each.value.name
  image_id               = data.aws_ami.rabbitmq.image_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id, data.aws_security_group.public_ips.id]
  user_data              = base64encode(data.template_file.init[each.key].rendered)
  key_name               = local.key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  iam_instance_profile {
    name = var.instance_profile
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.default_tags, {
      Account = data.aws_iam_account_alias.this.account_alias
      Name    = each.value.name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.default_tags, {
      Account = data.aws_iam_account_alias.this.account_alias
      Name    = each.value.name
    })
  }

  tags = merge(var.default_tags, {
    App    = var.name
  })
}

resource "aws_autoscaling_group" "rabbit_per_az" {
  for_each                  = local.az_with_context
  name                      = each.value.name
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 180
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true

  launch_template {
    id      = aws_launch_template.rabbit_per_az[each.key].id
    version = "$Latest"
  }

  vpc_zone_identifier = each.value.subnet_ids

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }
}



# Create Target Groups Attachments
resource "aws_autoscaling_attachment" "http" {
  for_each               = local.az_with_context
  autoscaling_group_name = aws_autoscaling_group.rabbit_per_az[each.key].id
  lb_target_group_arn    = aws_lb_target_group.tg_internal_http.arn
}


resource "aws_autoscaling_attachment" "amqp" {
  for_each               = local.az_with_context
  autoscaling_group_name = aws_autoscaling_group.rabbit_per_az[each.key].id
  lb_target_group_arn    = aws_lb_target_group.tg_external_amqp.arn
}

resource "aws_autoscaling_attachment" "amqp_internal" {
  for_each               = local.az_with_context
  autoscaling_group_name = aws_autoscaling_group.rabbit_per_az[each.key].id
  lb_target_group_arn    = aws_lb_target_group.tg_internal_amqp.arn
}

resource "aws_autoscaling_attachment" "consul_http" {
  for_each               = local.az_with_context
  autoscaling_group_name = aws_autoscaling_group.rabbit_per_az[each.key].id
  lb_target_group_arn    = aws_lb_target_group.tg_internal_consul_http.arn
}
