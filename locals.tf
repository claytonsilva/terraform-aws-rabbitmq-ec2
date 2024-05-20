locals {
  lb_name          = "nlb-${var.name}"
  lb_name_internal = "${local.lb_name}-internal"
  az_with_context = {
    for k in data.aws_subnet.private : k.availability_zone => {
      name       = "${var.name}-${k.availability_zone}"
      subnet_ids = [k.id]
    }
  }

  role_name              = var.role_name == "" ? var.name : var.role_name
  key_name               = var.key_name == "" ? null : var.key_name
  secret_policy_document = var.secret_kms_arn != "" ? data.secret_manager_ronly_crypt[0].json : data.secret_manager_ronly[0].json

  vpc_id   = data.aws_vpc.this.id
  vpc_cidr = data.aws_vpc.this.cidr_block


  rabbitmq_service_external_ports = {
    5672 = "Amqp Port"
    5671 = "Amqps Port"
  }

  rabbit_service_internal_ports = {
    80    = "Management Consul Dashboard"
    443   = "Management HTTPS"
    5672  = "Amqp Port"
    5671  = "Amqps Port"
    8500  = "Consul Default"
    15672 = "Management Default"
  }

  ami_regex = var.ami_regex == "" ? "^${var.name}-" : var.ami_regex

  secret_ids = {
    admin_password      = "admin-password"
    monitor_password    = "monitor-password"
    terraform_password  = "terraform-password"
    cookie_string       = "cookie"
    federation_password = "federation-password"
    newrelic_key        = "nri-infrastructure-key"
  }

  all_private_subnets = flatten([for k, v in local.az_with_context : v.subnet_ids])
  all_public_subnets  = data.aws_subnets.public.ids

  ### extracting extra infos from ecr repo pattern
  ecr_repo_dns = split("/", var.rabbit_image_url)[0]
  ecr_region   = split(".", var.rabbit_image_url)[3]
}
