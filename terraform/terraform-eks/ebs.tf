resource "aws_ebs_volume" "mysql_volume" {
  availability_zone = "${var.aws_region}a"
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = {
    Name      = "mysql-ebs"
    Project   = "AutoOps"
    ManagedBy = "Terraform"
    Purpose   = "MySQL-PersistentStorage"
  }
}
