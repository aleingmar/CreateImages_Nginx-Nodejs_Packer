####################################################################################################
# BLOQUE DE ENTRADA
####################################################################################################

# CONFIGURACIÓN DE TERRAFORM PARA PROVEEDOR AWS
# Este bloque define el proveedor de Terraform que se usará, en este caso AWS.
# La región de AWS se pasa como una variable (aws_region).
provider "aws" {
  region = var.aws_region
}

####################################################################################################
# RECURSO LOCAL PARA EJECUTAR PACKER Y CREAR LA AMI
# Este recurso utiliza un comando local (en la maquina que ejecuta terraform init) para ejecutar Packer con las variables necesarias
# y generar la AMI basada en el archivo de configuración de Packer (main.pkr.hcl).
resource "null_resource" "packer_ami" {
  provisioner "local-exec" {
    command = "packer build -var aws_access_key=${var.aws_access_key} -var aws_secret_key=${var.aws_secret_key} -var aws_session_token=${var.aws_session_token} -var-file=..\\packer\\variables.pkrvars.hcl ..\\packer\\main.pkr.hcl"
  }
}




####################################################################################################

#  RECURSO (de datos) PARA RECUPERAR LA ÚLTIMA AMI CREADA
# Este bloque obtiene la AMI más reciente creada por el recurso anterior.
# Filtra las AMIs basadas en el nombre de la AMI y el propietario (self indica el usuario actual).
data "aws_ami" "latest_ami" {
  depends_on = [null_resource.packer_ami] # Asegura que este bloque espere la creación de la AMI
  most_recent = true # Selecciona la AMI más reciente.
  filter {
    name   = "name" # Filtro por nombre.
    values = ["${var.ami_name}*"] # Coincidencia parcial con el nombre base definido en las variables.
  }
  owners = ["self"] # Solo busca AMIs creadas por el propietario actual.
}


# RECURSO PARA RECUPERAR LA VPC POR DEFECTO
data "aws_vpc" "default" {
  default = true
}


####################################################################################################

# Configuración de seguridad: Grupo de seguridad para EC2
# Este bloque define un grupo de seguridad para gestionar el tráfico hacia la instancia.
resource "aws_security_group" "web_server_sg" {
  name        = "${var.instance_name}-sg" # Nombre del grupo de seguridad.
  description = "Grupo de seguridad para la instancia EC2"
  vpc_id = data.aws_vpc.default.id # ID de la VPC donde se creará el grupo de seguridad.
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [name]
  }
  # Reglas de ingreso: permite acceso HTTP y SSH.
  ingress {
    description      = "Permitir trafico HTTP"
    from_port        = 80 # Puerto HTTP.
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Permite acceso desde cualquier lugar.
  }

  ingress {
    description      = "Permitir trafico HTTPS"
    from_port        = 443 # Puerto HTTPS.
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Permitir acceso SSH"
    from_port        = 22 # Puerto SSH.
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Cambia esto a una IP específica para mayor seguridad.
  }

  # Reglas de egreso: permite todo el tráfico de salida.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # Permite todos los protocolos.
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
####################################################################################################
# RECURSO PARA CONFIGURAR LA INSTANCIA DE EC2
# Este recurso lanza una instancia EC2 usando la AMI recuperada en el bloque anterior.
# Asocia el grupo de seguridad a la instancia EC2
resource "aws_instance" "web_server" {
  ami                   = data.aws_ami.latest_ami.id
  instance_type         = var.instance_type
  key_name              = var.key_name
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  tags = {
    Name = var.instance_name
  }

  # Configuración de conexión SSH
  connection {
    type        = "ssh"
    user        = "ubuntu" # Usuario predeterminado para AMIs de Ubuntu
    private_key = file("C:\\Users\\User\\.aws\\unir.pem") # Ruta a la clave privada
    host        = self.public_ip
  }

  # Provisionador remoto para ejecutar comandos
  provisioner "remote-exec" {
    inline = [
      "echo 'La instancia está configurada correctamente.'"
    ]
  }
}
####################################################################################################

####################################################################################################
# BLOQUE DE SALIDA
####################################################################################################

# Bloques de salida
# Estos bloques definen las salidas que se mostrarán al usuario al finalizar el despliegue.
# Se incluye el ID de la instancia y su dirección IP pública.

# Muestra el ID de la instancia creada
output "instance_id" {
  value = aws_instance.web_server.id
}

# Muestra la dirección IP pública de la instancia creada
output "public_ip" {
  value = aws_instance.web_server.public_ip
}

####################################################################################################
####################################################################################################
# DESPLEGAR TERRAFORM
# terraform init --> Inicializa el directorio de trabajo
# terraform plan -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token" --> Muestra los cambios que se realizarán
# terraform apply -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token"--> Aplica los cambios y despliega la infraestructura
# terraform destroy --> Elimina la infraestructura creada