variable "default_tags" {
  description = "tags used in application running"
  type        = map(string)
  default     = {}
}
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}
variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}
variable "region" {
  description = "region"
  type        = string
}
variable "source_ami" {
  description = "value"
  type        = string
  default     = "ami-07ce5684ee3b5482c"
}
variable "instance_type" {
  description = "instance type"
  type        = string
  default     = "t4g.medium"
}
