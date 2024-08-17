###################################
## Data
###################################
data "aws_iam_account_alias" "this" {}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      identifiers = [
        "ec2.amazonaws.com"
      ]
      type = "Service"
    }
  }
}

data "aws_secretsmanager_secret" "this" {
  arn = var.secret_arn
}

data "aws_ami" "rabbitmq" {
  most_recent = true
  name_regex  = local.ami_regex
  owners      = ["self"]
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "instances" {
  for_each = toset(var.instances_subnet_ids)
  id       = each.value
}

data "aws_route53_zone" "hosted_zone" {
  provider = aws.route53_account
  name     = var.domain_name
}




data "template_file" "init" {
  for_each = local.az_with_context
  template = file("init.sh")
  vars = {
    region                          = var.region
    domain                          = var.consul_domain
    cluster_name                    = var.cluster_name
    name                            = each.value.name
    admin_username                  = "admin"
    monitor_username                = "monitor"
    federation_username             = "federation"
    tag_key_app                     = "App"
    tag_app                         = var.name
    secret_name                     = data.aws_secretsmanager_secret.this.id
    secret_id_admin_password        = local.secret_ids.admin_password
    secret_id_terraform_password    = local.secret_ids.terraform_password
    secret_id_monitor_password      = local.secret_ids.monitor_password
    secret_id_federation_password   = local.secret_ids.federation_password
    secret_id_cookie_string         = local.secret_ids.cookie_string
    secret_id_newrelic_key          = local.secret_ids.newrelic_key
    filesystem_id                   = aws_efs_file_system.rabbit_data.id
    ecr_repo_dns                    = local.ecr_repo_dns
    ecr_region                      = local.ecr_region
    rabbitmq_image_url              = var.rabbit_image_url
    rabbitmq_delayedmessage_version = var.rabbit_delayedmessage_version
  }
}

data "aws_iam_policy_document" "secret_manager_ronly_crypt" {
  for_each = local.has_kms
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      var.secret_kms_arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      var.secret_arn
    ]
  }
}

data "aws_iam_policy_document" "secret_manager_ronly" {
  for_each = local.does_not_have_kms
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      var.secret_arn
    ]
  }
}
