packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
    azure-arm = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

#######################################################################################################################
# VARIABLES
#######################################################################################################################
# a las credenciales de AWS y Azureles voy a asignar valores por defecto, por si no se pasan al ejecutar el comando
variable "aws_region" { description = "Región de AWS" }
variable "ami_name" { description = "Nombre de la AMI generada" }
variable "instance_type" { description = "Tipo de instancia de AWS" }
variable "project_name" { description = "Nombre del proyecto" }
variable "environment" { description = "Entorno del proyecto (dev, test, prod)" }
# Credenciales de AWS
variable "aws_access_key" { 
  description = "Clave de acceso de AWS" 
  default = "default"
}
variable "aws_secret_key" { 
  description = "Clave secreta de AWS" 
  default = "default"
}
variable "aws_session_token" { 
  description = "Token de sesión de AWS" 
  default = "default"
}

variable "azure_image_name" { description = "Nombre de la imagen para Azure" }
variable "azure_region" { description = "Región de Azure" }
variable "azure_instance_type" { description = "Tipo de instancia en Azure"  }
variable "azure_admin_username" { description = "Usuario administrador para Azure"  }
variable "azure_admin_password" { description = "Contraseña del administrador para Azure"  }
variable "azure_resource_group_name" { description = "Nombre del grupo de recursos de Azure" }
# CREDENCIALES (no hace falta definirlas creo)
variable "azure_subscription_id" { 
  description = "ID de la suscripción de Azure" 
  default = "default"
}
variable "azure_client_id" { 
  description = "ID de la aplicación (cliente) en Azure" 
  default = "default"
}
variable "azure_client_secret" { 
  description = "Clave secreta de la aplicación (cliente) en Azure" 
  default = "default"
}
variable "azure_tenant_id" { 
  description = "ID del inquilino en Azure" 
  default = "default"
}

#######################################################################################################################
# AWS BUILDER
#######################################################################################################################
source "amazon-ebs" "aws_builder" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  token         = var.aws_session_token
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
source "azure-arm" "azure_builder" {
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id

  managed_image_name                = var.azure_image_name
  managed_image_resource_group_name = var.azure_resource_group_name
  #managed_image_resource_group_name=  "${var.instance_name}-rg"
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
  name    = "cloud-node-nginx"
  sources = ["source.amazon-ebs.aws_builder", "source.azure-arm.azure_builder"]

  # Primer provisioner: ejecuta comandos de shell en la instancia
  provisioner "shell" {                             
    inline = [
      "sudo apt update -y",                         # Actualiza la lista de paquetes
      "sudo apt install -y nginx",                 # Instala el servidor web Nginx
      "curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -", # Configura el repositorio para instalar Node.js 14
      "sudo apt install -y nodejs build-essential", # Instala Node.js y herramientas de construcción esenciales
      "sudo npm install pm2@latest -g",            # Instala PM2 globalmente para gestionar procesos Node.js
      "sudo ufw allow 'Nginx Full'",               # Configura el firewall para permitir tráfico HTTP y HTTPS para Nginx
      "sudo systemctl enable nginx"                # Habilita el servicio Nginx para que se inicie automáticamente
    ]
  }

  # Segundo provisioner: transfiere un archivo desde el host a la instancia
  provisioner "file" {                              
    source      = "../packer/provisioners/app.js"            # Ruta del archivo en el host
    destination = "/home/ubuntu/app.js"            # Ruta de destino en la instancia
  }

  # Tercer provisioner: configura la aplicación Node.js con PM2 (gestor de procesos de Node.js)
  provisioner "shell" {
    inline = [
      "sudo pm2 start /home/ubuntu/app.js",               # Inicia la aplicación como root
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd --hp /root", # Configura PM2 para autoarranque como root
      "sudo pm2 save",                                    # Guarda el estado de PM2 en /root/.pm2/dump.pm2
      "sudo cp /root/.pm2/dump.pm2 /etc/pm2-dump.pm2 || true" # Copia el dump a una ubicación segura (opcional)
    ]
  }

  ### Provisioners (4 y 5) para configurar Nginx como proxy inverso

  # Cuarto provisioner: Copiar el archivo de configuración de Nginx al servidor
  provisioner "file" {
    source      = "../packer/provisioners/nginx_default.conf"
    destination = "/tmp/nginx_default"
  }

  # Quinto provisioner:Configuración de Nginx como proxy inverso y validación
  provisioner "shell" {
    inline = [
      # Copia la configuración de Nginx
      "sudo cp /tmp/nginx_default /etc/nginx/sites-available/default",
      # Prueba la configuración de Nginx
      "sudo nginx -t",
      # Reinicia el servicio de Nginx
      "sudo systemctl restart nginx",
      # Valida que el servidor está funcionando
      "curl -I localhost"
    ]
  }
}
