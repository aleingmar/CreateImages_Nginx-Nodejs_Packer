# Plantilla de Packer para crear una imagen para AWS con Ubuntu 20.04, Nginx y Node.js

########################################################################################################################
# PLUGINS: Define los plugins necesarios para la plantilla
# Para descargar el plugin necesario para la plantilla, levantar la imagen en VirtualBox
# se puede instalar tambien directamente con # packer plugins install github.com/hashicorp/virtualbox

packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}


# Variables externas
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_session_token" {}
variable "aws_region" {}
variable "ami_name" {}
variable "instance_type" {}
variable "project_name" {}
variable "environment" {}
##########################################################################################################
# BUILDER: Define cómo se construye la AMI en AWS
# source{}--> define el sistema base sobre el que quiero crear la imagen (ISO ubuntu) y el proveeedor para el que creamos la imagen 
# (tecnologia con la que desplegará la imagen) --> AMAZON
source "amazon-ebs" "aws_builder" {
  #variables importadas del fichero de variables
  # access_key    = var.aws_access_key
  # secret_key    = var.aws_secret_key
  # token         = var.aws_session_token
  # region        = var.aws_region
  #variables de entorno (estan en mi host)
  access_key    = "${env("AWS_ACCESS_KEY")}"
  secret_key    = "${env("AWS_SECRET_KEY")}"
  token         = "${env("AWS_SESSION_TOKEN")}"
  region        = var.aws_region
  ## OPCION 1 --> Seleccionar una AMI específica
  #source_ami = "ami-095a8f574cb0ac0d0" # AMI de Ubuntu 20.04 LTS

  ## OPCION 2 --> Seleccionar la AMI más reciente
  # Esto busca la AMI más reciente de Ubuntu 20.04 con las caracteristicas especificadas (región especificada,ebs...)
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners       = ["099720109477"] # Propietario de las AMIs de Ubuntu (Canonical)
    most_recent  = true
  }

  instance_type = var.instance_type # Instancia recomendada para AMIs de Ubuntu (t2.micro), esta en el fichero de variables
  ssh_username  = "ubuntu"    # Usuario predeterminado en AMIs de Ubuntu
  ami_name      = "${var.ami_name}-${timestamp()}"
}


#######################################################################################################################
# PROVISIONERS: Configura el sistema operativo y la aplicación
# build{}: Describe cómo se construirá la imagen --> Definir los provisioners para instalar y configurar software
build {
  name    = "aws-node-nginx"
  sources = ["source.amazon-ebs.aws_builder"]

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
    source      = "provisioners/app.js"
    destination = "/home/ubuntu/app.js"
  }

  provisioner "shell" {
    inline = [
      "pm2 start /home/ubuntu/app.js",
      "pm2 save",
      "pm2 startup"
    ]
  }
}

####################################################################################################
##### PASOS PARA EJECUTAR
# packer init -var-file=variables/variables.hcl main.pkr.hcl, descarga los plugins necesarios
# packer validate -var-file=variables/variables.hcl main.pkr.hcl , VERIFICA SINTAXIS DE LA PLANTILLA
# packer inspect -var-file=variables/variables.hcl main.pkr.hcl, MUESTRA LA CONFIGURACIÓN DE LA PLANTILLA

# packer build -var-file=variables/variables.hcl main.pkr.hcl, GENERA LA IMAGEN A PARTIR DE LA PLANTILLA

