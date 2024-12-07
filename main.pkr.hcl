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

#######################################################################################################################
# Variables de la plantilla

variable "aws_region" {
  description = "Región de AWS"
}

variable "ami_name" {
  description = "Nombre de la AMI generada"
}

variable "instance_type" {
  description = "Tipo de instancia de AWS"
}

variable "project_name" {
  description = "Nombre del proyecto"
}

variable "environment" {
  description = "Entorno del proyecto (dev, test, prod)"
}

variable "aws_access_key" {
  description = "Clave de acceso de AWS"
}

variable "aws_secret_key" {
  description = "Clave secreta de AWS"
}

variable "aws_session_token" {
  description = "Token de sesión de AWS"
}

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
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  token         = var.aws_session_token
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
  #ami_name      = "${var.ami_name}-${timestamp()}"
  ami_name = "Actividad_Node_Nginx_AMI"

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
# packer init main.pkr.hcl, descarga los plugins necesarios
# packer validate -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token" `  -var-file="variables/variables.pkrvars.hcl" main.pkr.hcl, VERIFICA SINTAXIS DE LA PLANTILLA
# packer inspect -var-file=variables/variables.hcl main.pkr.hcl, MUESTRA LA CONFIGURACIÓN DE LA PLANTILLA

# packer build -var-file=variables/variables.hcl main.pkr.hcl, GENERA LA IMAGEN A PARTIR DE LA PLANTILLA

