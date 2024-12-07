
# Plantilla de Packer para crear una imagen de VirtualBox con Ubuntu 20.04, Nginx y Node.js

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
##############
##########################################################################################################
# SOURCE--> define el sistema base sobre el que quiero crear la imagen (ISO ubuntu) y el proveeedor para el que creamos la imagen 
# (tecnologia con la que desplegará la imagen) --> VirtualBox
source "amazon-ebs" "ubuntu" {
  ami_name      = "packer-node-nginx-{{timestamp}}"
  instance_type = "t2.micro" # Usa el tipo gratuito si estás en Free Tier
  region        = "us-east-1"
  source_ami    = "ami-0c55b159cbfafe1f0" # Ubuntu 20.04 en la región us-east-1
  ssh_username  = "ubuntu"
  ami_description = "AMI con Node.js y Nginx preinstalados."
  associate_public_ip_address = true
}

########################################################################################################################
# BUILD: Describe cómo se construirá la imagen --> Definir los provisioners para instalar y configurar software
build {
  name    = "aws-node-nginx"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "file" {
    source      = "app.js"          # Archivo de la aplicación Node.js
    destination = "/home/ubuntu/app.js"
  }

  provisioner "shell" {
    inline = [
      # Actualización del sistema
      "sudo apt update -y",
      "sudo apt upgrade -y",

      # Instalación de Node.js
      "curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh",
      "sudo bash nodesource_setup.sh",
      "sudo apt install -y nodejs build-essential",

      # Configuración de la aplicación Node.js
      "mkdir -p /var/www/app",
      "sudo mv /home/ubuntu/app.js /var/www/app/app.js",
      "sudo npm install pm2@latest -g",
      "pm2 start /var/www/app/app.js",
      "pm2 save",
      "pm2 startup systemd -u ubuntu --hp /home/ubuntu",

      # Instalación y configuración de Nginx
      "sudo apt install -y nginx",
      "echo 'server { listen 80; location / { proxy_pass http://127.0.0.1:3000; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection \"upgrade\"; proxy_set_header Host $host; proxy_cache_bypass $http_upgrade; }}' | sudo tee /etc/nginx/sites-available/default",
      "sudo nginx -t",
      "sudo systemctl restart nginx",

      # Ajustes de firewall (permitir tráfico HTTP y HTTPS en AWS)
      "sudo ufw allow 'Nginx Full'",
      "sudo systemctl enable nginx"
    ]
  }
}
####################################################################################################
##### PASOS PARA EJECUTAR
# packer validate template.pkr.hcl , VERIFICA SINTAXIS DE LA PLANTILLA
# packer inspect template.pkr.hcl, MUESTRA LA CONFIGURACIÓN DE LA PLANTILLA
# packer init template.pkr.hcl, descarga los plugins necesarios
# packer build template.pkr.hcl, GENERA LA IMAGEN A PARTIR DE LA PLANTILLA

#####Entra a la máquina manualmente usando las credenciales:
#Usuario: ubuntu
#Contraseña: ubuntu
#Abre un navegador en tu máquina host (Windows) y visita http://localhost

#########################################################33

  # boot_command = [             
  #   "<esc><wait>",
  #   "linux auto-install/enable=true ",
  #   "debian-installer/locale=en_US ",
  #   "kbd-chooser/method=us ",
  #   "netcfg/get_hostname=ubuntu ",
  #   "netcfg/get_domain=localdomain ",
  #   "fb=false ",
  #   "console-setup/ask_detect=false ",
  #   "console-keymaps-at/keymap=us ",
  #   "keyboard-configuration/xkb-keymap=us ",
  #   "initrd=/casper/initrd ",
  #   "quiet --- <enter>"
  # ]