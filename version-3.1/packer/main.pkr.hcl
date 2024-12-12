packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
    azurerm = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azurerm"
    }
  }
}

#######################################################################################################################
# VARIABLES
#######################################################################################################################
variable "aws_region" { description = "Región de AWS" }
variable "ami_name" { description = "Nombre de la AMI generada" }
variable "instance_type" { description = "Tipo de instancia de AWS" }
variable "project_name" { description = "Nombre del proyecto" }
variable "environment" { description = "Entorno del proyecto (dev, test, prod)" }


variable "azure_image_name" { description = "Nombre de la imagen para Azure" }
variable "azure_region" { description = "Región de Azure" }
variable "azure_instance_type" { description = "Tipo de instancia en Azure"  }
variable "azure_admin_username" { description = "Usuario administrador para Azure"  }
variable "azure_admin_password" { description = "Contraseña del administrador para Azure"  }
variable "azure_resource_group_name" { description = "Nombre del grupo de recursos de Azure" }
# CREDENCIALES (no hace falta definirlas creo)
# variable "azure_subscription_id" { description = "ID de la suscripción de Azure" }
# variable "azure_client_id" { description = "ID de la aplicación (cliente) en Azure" }
# variable "azure_client_secret" { description = "Clave secreta de la aplicación (cliente) en Azure" }
# variable "azure_tenant_id" { description = "ID del inquilino en Azure" }

#######################################################################################################################
# AWS BUILDER
#######################################################################################################################
source "amazon-ebs" "aws_builder" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  region        = var.aws_region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  instance_type = var.instance_type
  ssh_username  = "ubuntu"
  ami_name      = var.ami_name
  tags = {
    Name = "Packer-Builder"
  }
}

#######################################################################################################################
# AZURE BUILDER
#######################################################################################################################
source "azurerm" "azure_builder" {
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id

  managed_image_name                = var.azure_image_name
  managed_image_resource_group_name = var.azure_resource_group_name
  location                          = var.azure_region

  os_type     = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer"
  image_sku       = "20.04-LTS"
  azure_tags = {
    environment = var.environment
  }
}


#######################################################################################################################
# PROVISIONERS (SAME FOR BOTH CLOUD (AWS AND AZURE))
#######################################################################################################################
build {
  name    = "aws-node-nginx"
  sources = ["source.amazon-ebs.aws_builder", "source.azurerm.azure_builder"]

  provisioner "shell" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y nginx",
      "curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -",
      "sudo apt install -y nodejs build-essential",
      "sudo npm install pm2@latest -g",
      "sudo ufw allow 'Nginx Full'",
      "sudo systemctl enable nginx"
    ]
  }

  provisioner "file" {
    source      = "../packer/provisioners/app.js"
    destination = "/home/ubuntu/app.js"
  }

  provisioner "shell" {
    inline = [
      "sudo pm2 start /home/ubuntu/app.js",
      "sudo pm2 save",
      "sudo systemctl restart nginx"
    ]
  }
}
