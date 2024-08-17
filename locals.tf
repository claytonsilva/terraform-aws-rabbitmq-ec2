locals {

  account_alias = data.aws_iam_account_alias.this.account_alias
  lb_name       = "nlb-${var.name}"
  az_with_context = {
    for k in data.aws_subnet.instances : k.availability_zone => {
      name       = "${var.name}-${k.availability_zone}"
      subnet_ids = [k.id]
    }
  }

  has_kms           = var.secret_kms_arn != "" ? toset(["this"]) : toset()
  does_not_have_kms = var.secret_kms_arn == "" ? toset(["this"]) : toset()


  role_name              = var.role_name == "" ? var.name : var.role_name
  key_name               = var.key_name == "" ? null : var.key_name
  secret_policy_document = length(local.has_kms) > 0 ? data.aws_iam_policy_document.secret_manager_ronly_crypt["this"].json : data.aws_iam_policy_document.secret_manager_ronly["this"].json

  vpc_id   = data.aws_vpc.this.id
  vpc_cidr = data.aws_vpc.this.cidr_block

  nlb_listener_ports = {
    "management" = { description = "Management HTTP", port = "80", secure = false, ssl_policy = null, certificate_arn = null, service_port = "consul" }
    "https"      = { description = "HTTPS", port = "443", secure = true, ssl_policy = var.default_ssl_policy, certificate_arn = var.certificate_arn, service_port = "management" }
    "amqps"      = { description = "Amqps Port", port = "5671", secure = true, ssl_policy = var.default_ssl_policy, certificate_arn = var.certificate_arn, service_port = "amqp" }
  }

  nlb_service_ports_with_azs = tomap({
    for az_service_port in flatten([
      for k, v in local.az_with_context : [
        for inner_k, inner_v in local.nlb_listener_ports : {
          id           = "${k}-${inner_k}"
          zone_id      = k
          service_port = inner_v.service_port
        }
      ]
    ]) : az_service_port.id => az_service_port
  })

  rabbit_service_ports = {
    "management" = { description = "Rabbitmq Management HTTP", port = "15672" }
    "amqp"       = { description = "Amqp Port", port = "5672", }
    "amqps"      = { description = "Amqps Port", port = "5671", }
    "consul"     = { description = "Consul Default", port = "8500", }
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

  ### extracting extra infos from ecr repo pattern
  ecr_repo_dns = split("/", var.rabbit_image_url)[0]
  ecr_region   = split(".", var.rabbit_image_url)[3]
}
