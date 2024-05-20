variable "name" {
  description = "name of the group resource"
  type        = string
  default     = "rabbitmq-cluster"
}
variable "region" {
  description = "region of the resources"
  type        = string
}
variable "key_name" {
  description = "key used as fallback of the ssm access in instances"
  type        = string
  default     = ""
}
variable "instance_profile" {
  description = "instance profile used in ec2 resources"
  type        = string
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "consul_domain" {
  type    = string
  default = "consul"
}
variable "cluster_name" {
  type    = string
  default = "rabbitmq-cluster"
}
variable "ami_regex" {
  type    = string
  default = "rabbitmq"
}
variable "role_name" {
  description = "name of the role created by rabbitmq"
  type        = string
}
variable "secret_arn" {
  description = "arn of the secret used in the rabbitmq solution"
  type        = string
}
variable "secret_kms_arn" {
  description = "arn of the kms used in secret manager"
  type        = string
}
variable "vpc_id" {
  description = "id of the vpc used in cluster"
  type        = string
}
variable "private_subnet_ids" {
  description = "id of the private subnet ids for internal load balancer"
}
variable "default_tags" {
  description = "Default tags"
  type        = map(string)
}
variable "certificate_arn" {
  type = string
}
variable "hosted_zone" {
  type = string
}
variable "domain_name" {
  type = string
}
variable "rabbit_image_url" {
  type = string
}
variable "rabbit_delayedmessage_version" {
  type = string
}
