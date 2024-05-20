resource "aws_iam_role" "this" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags = merge(
    {
      Name = local.role_name
    },
    var.default_tags
  )
}

resource "aws_iam_role_policy" "secret_manager_ronly" {
  role   = aws_iam_role.this.name
  name   = "secret_manager_ronly"
  policy = local.secret_policy_document
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  policy_arn = "arn:aws:iam::350085234395:policy/CloudWatchLogsRole"
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "ec2ronly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "ecrronly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.this.name
}

resource "aws_iam_instance_profile" "this" {
  name = local.role_name
  role = aws_iam_role.this.name
}
