#tfsec:ignore:AWS048
resource "aws_efs_file_system" "rabbit_data" {
  tags = var.default_tags

  lifecycle {
    ignore_changes = [size_in_bytes]
  }
}

resource "aws_efs_mount_target" "alpha" {
  for_each        = local.az_with_context
  file_system_id  = aws_efs_file_system.rabbit_data.id
  subnet_id       = each.value.subnet_ids[0]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.rabbit_data.id

  backup_policy {
    status = "ENABLED"
  }
}
