resource "aws_launch_template" "rabbit_per_az" {
  for_each               = local.az_with_context
  name                   = each.value.name
  image_id               = data.aws_ami.rabbitmq.image_id
  instance_type          = var.instance_type
  vpc_security_group_ids = concat(var.additional_sg_instances_ids, aws_security_group.main.id)
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
      Account = local.account_alias
      Name    = each.value.name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.default_tags, {
      Account = local.account_alias
      Name    = each.value.name
    })
  }

  tags = merge(var.default_tags, {
    App = var.name
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
resource "aws_autoscaling_attachment" "this" {
  for_each               = local.nlb_service_ports_with_azs
  autoscaling_group_name = aws_autoscaling_group.rabbit_per_az[each.value.az].id
  lb_target_group_arn    = aws_lb_target_group.this[each.value.service_port].arn
}
