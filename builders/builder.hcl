# Configuración del builder para AWS

source "amazon-ebs" "aws_builder" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  region        = var.aws_region

  # Filtra la AMI base desde la que se creará la nueva imagen
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners       = ["099720109477"] # Canonical (propietario oficial de Ubuntu en AWS)
    most_recent  = true
  }

  instance_type = var.instance_type
  ssh_username  = "ubuntu"
  ami_name      = "${var.ami_name}-${timestamp()}"
}
