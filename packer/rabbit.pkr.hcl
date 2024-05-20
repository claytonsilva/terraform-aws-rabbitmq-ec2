source "amazon-ebs" "amazon" {
  region                  = var.region
  source_ami              = var.source_ami
  ami_virtualization_type = "hvm"
  instance_type           = "t4g.medium"
  ssh_username            = "ec2-user"
  ami_name                = "rabbitmq-{{timestamp}}"
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    throughput            = 300
    iops                  = 3000
  }
  tags     = var.default_tags
  run_tags = var.default_tags
  subnet_filter {
    filters = {
      "vpc-id" : var.vpc_id,
      "subnet-id" : var.subnet_id
    }
  }
}

build {
  sources = ["source.amazon-ebs.amazon"]
  provisioner "ansible" {
    # type          = "ansible"
    playbook_file = "./ansible/builder.yml"
    ansible_env_vars = [
      "no_proxy=\"*\""
    ]
    extra_arguments = [
      "--scp-extra-args",
      "'-O'"
    ]
  }
}
