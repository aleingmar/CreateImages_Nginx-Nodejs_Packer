# Plantilla de Packer para crear una imagen para AWS con Ubuntu 20.04, Nginx y Node.js

########################################################################################################################
# PLUGINS: Define los plugins necesarios para la plantilla
# Para descargar el plugin necesario para la plantilla, levantar la imagen en AWS

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

variable "aws_region" { description = "Región de AWS" }
variable "ami_name" { description = "Nombre de la AMI generada" }
variable "instance_type" { description = "Tipo de instancia de AWS" }
variable "project_name" { description = "Nombre del proyecto" }
variable "environment" { description = "Entorno del proyecto (dev, test, prod)" }
# Credenciales de AWS
variable "aws_access_key" { description = "Clave de acceso de AWS" }
variable "aws_secret_key" { description = "Clave secreta de AWS" }
variable "aws_session_token" { description = "Token de sesión de AWS" }

##########################################################################################################
# BUILDER: Define cómo se construye la AMI en AWS
# source{}--> define el sistema base sobre el que quiero crear la imagen (ISO ubuntu) y el proveeedor para el que creamos la imagen 
# (tecnologia con la que desplegará la imagen) --> AMAZON
source "amazon-ebs" "aws_builder" {
  #variables importadas del fichero de variables
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
  ami_name = var.ami_name
  tags = {
    Name = "Packer-Builder" # Nombre descriptivo para la instancia Packer.
  }

}


#######################################################################################################################
# PROVISIONERS: Configura el sistema operativo y la aplicación
# build{}: Describe cómo se construirá la imagen --> Definir los provisioners para instalar y configurar software
build {
  name    = "aws-node-nginx"                        # Nombre del proceso de construcción
  sources = ["source.amazon-ebs.aws_builder"]       # Especifica el builder que utilizará esta configuración

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


####################################################################################################
##### IMPORTANTE para automatizar el proceso de despliegue con Terraform, he cambiado las direcciones 
# de los archivos provisioners/app.js y provisioners/nginx_default.conf a sus rutas relativas desde el punto de vista del main.tf (../packer/provisioners/)

##### PASOS PARA EJECUTAR (EN WINDOWS, desde la carpeta packer, solo la creacion de imagen)
# packer init main.pkr.hcl, descarga los plugins necesarios
# packer validate -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token" `  -var-file="variables/variables.pkrvars.hcl" main.pkr.hcl, VERIFICA SINTAXIS DE LA PLANTILLA
# packer inspect -var-file=variables/variables.hcl main.pkr.hcl, MUESTRA LA CONFIGURACIÓN DE LA PLANTILLA

# packer build -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token" `  -var-file="variables/variables.pkrvars.hcl" main.pkr.hcl, GENERA LA IMAGEN A PARTIR DE LA PLANTILLA

