provider "aws" {
  region = var.aws_region
}

# Módulo local para ejecutar Packer
resource "null_resource" "packer_ami" {
  provisioner "local-exec" {
    command = <<EOT
      packer build -var "aws_access_key=${var.aws_access_key}" \
                   -var "aws_secret_key=${var.aws_secret_key}" \
                   -var "aws_session_token=${var.aws_session_token}" \
                   -var "aws_region=${var.aws_region}" \
                   -var "ami_name=${var.ami_name}" \
                   ../packer/main.pkr.hcl
    EOT
  }
}

# Obtener el ID de la AMI creada
data "aws_ami" "latest_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami_name}*"]
  }
  owners = ["self"]
}

# Crear una instancia EC2 desde la AMI
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.latest_ami.id
  instance_type = var.instance_type
  key_name      = var.key_name

  tags = {
    Name = var.instance_name
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'La instancia está corriendo y configurada'"
    ]
  }
}

# Outputs
output "instance_id" {
  value = aws_instance.web_server.id
}

output "public_ip" {
  value = aws_instance.web_server.public_ip
}


#######################################################
########33 Comandos para Desplegar

# terraform init # Inicializar Terraform:

# terraform plan # Revisar el Plan:

# terraform apply # Aplicar el Plan:
# Validar el Despliegue: Terraform mostrará los valores de salida (instance_id y public_ip). Puedes usar la IP pública para verificar que tu aplicación está corriendo:
# curl http://<PUBLIC_IP>

# 4. Limpieza
# Para destruir la infraestructura y evitar costos innecesarios:

# terraform destroy