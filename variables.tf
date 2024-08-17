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
  description = "type of the instance of rabbitmq node"
  type        = string
  default     = "t4g.small"
}
variable "consul_domain" {
  description = "internal domain used in consul cluster"
  type        = string
  default     = "consul"
}
variable "cluster_name" {
  description = "name of the cluster"
  type        = string
  default     = "rabbitmq-cluster"
}
variable "ami_regex" {
  description = "regex to find the ami of the rabbitmq instances"
  type        = string
  default     = "rabbitmq"
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
variable "default_tags" {
  description = "Default tags"
  type        = map(string)
}
variable "certificate_arn" {
  description = "ARN of the certificate on AWS ACM tho attach with the load balancer"
  type        = string
}
variable "domain_name" {
  description = "domain name used by the cluster (we will find this domain in route53)"
  type        = string
}
variable "rabbit_image_url" {
  description = "rabbitmq image url from docker or custom index"
  type        = string
  default     = "3.13-management-alpine"
}
variable "rabbit_delayedmessage_version" {
  description = "version of the delayed message to be installed"
  type        = string
}
variable "instances_subnet_ids" {
  type        = set(string)
  description = "set of subnet id's to be used in RabbitMQ instances, to work correctly, we must fill with one subnet per az, and the length of the subnet must be 3"
}
variable "alb_subnet_ids" {
  type        = set(string)
  description = "subnets to be used in ALB"
}
variable "default_ssl_policy" {
  type        = string
  description = "default ssl policy used in SSL communications"
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}
variable "is_lb_internal" {
  type        = bool
  description = "define if the load balancer is internal or external"
  default     = true
}
variable "additional_sg_instances_ids" {
  # add check for only 5 security groups
  description = "aditional security group id's to add directly into instance in AutoScaling Group"
  type        = set(string)
  default     = []
}

variable "additional_sg_lb_ids" {
  # add check for only 5 security groups
  description = "aditional security group id's to add directly into load balancer"
  type        = set(string)
  default     = []
}
