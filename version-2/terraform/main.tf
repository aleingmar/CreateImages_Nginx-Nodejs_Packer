####################################################################################################
# CONFIGURACIÓN DE TERRAFORM PARA EL PROVEEDOR AWS
####################################################################################################
# Este bloque define el proveedor de Terraform que se usará, en este caso AWS.
provider "aws" {
  region = var.aws_region
}

####################################################################################################
# RECURSO PARA EJECUTAR PACKER Y GENERAR LA AMI
####################################################################################################
# Este recurso utiliza un comando local (en la maquina que ejecuta terraform init) para ejecutar Packer con las variables necesarias
# y generar la AMI basada en el archivo de configuración de Packer (main.pkr.hcl).
resource "null_resource" "packer_ami" {
  # local-exec ejecuta un comando en la máquina que ejecuta Terraform.
  provisioner "local-exec" {
    # Este comando invoca Packer para construir una AMI personalizada usando las variables y configuraciones proporcionadas.
    command = "packer build -var aws_access_key=${var.aws_access_key} -var aws_secret_key=${var.aws_secret_key} -var aws_session_token=${var.aws_session_token} -var-file=..\\packer\\variables.pkrvars.hcl ..\\packer\\main.pkr.hcl"
  }
}

####################################################################################################
# OBTENER LA ÚLTIMA AMI CREADA
####################################################################################################
data "aws_ami" "latest_ami" {
  depends_on = [null_resource.packer_ami] # Espera a que el provisioner "packer_ami" termine --> asegura que la AMI sea creada antes de intentar recuperarla.
  most_recent = true                      # Selecciona siempre la AMI más reciente.
  filter {
    name   = "name"                       # Filtra por el nombre de la AMI.
    values = ["${var.ami_name}*"]         # Busca nombres que coincidan parcialmente con el valor de la variable `ami_name`.
  }
  owners = ["self"]                       # Limita la búsqueda a las AMIs creadas por el propietario actual.
}

####################################################################################################
# OBTENER LA VPC POR DEFECTO (configuración de red virtual)
####################################################################################################
data "aws_vpc" "default" {
  default = true # Recupera la VPC predeterminada asociada a la cuenta AWS.
}

####################################################################################################
# CONFIGURACIÓN DEL GRUPO DE SEGURIDAD PARA LA INSTANCIA EC2
####################################################################################################
# Intentar buscar un grupo de seguridad existente basado en su nombre y VPC.
data "aws_security_group" "existing_sg" {
  # Filtro para buscar un grupo de seguridad por su nombre.
  filter {
    name   = "group-name"
    values = ["${var.instance_name}-sg"] # Nombre basado en la variable `instance_name`.
  }
  # Filtro para asegurarse de que pertenece a la VPC predeterminada.
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id] # ID de la VPC predeterminada.
  }

}
resource "aws_security_group" "web_server_sg" {
  # Crear un nuevo grupo de seguridad solo si no existe uno con el nombre especificado.
  count = try(data.aws_security_group.existing_sg.id != "", false) ? 0 : 1 # Condición para crear o no el recurso. (si no existe count=1, se crea uno nuevo), try es para que no falle si no hay
  name        = "${var.instance_name}-sg" # El nombre del grupo de seguridad se basa en el nombre de la instancia.
  description = "Grupo de seguridad para la instancia EC2" # Descripción del grupo.
  vpc_id      = data.aws_vpc.default.id  # Asocia este grupo de seguridad a la VPC predeterminada.
  
  #ingress --> trafico de entrada
  #egrress --> trafico de salida
  # Reglas de ingreso para permitir tráfico HTTP.
  ingress {
    description      = "Permitir trafico HTTP"
    from_port        = 80               # Puerto de entrada (HTTP).
    to_port          = 80
    protocol         = "tcp"            # Protocolo TCP.
    cidr_blocks      = ["0.0.0.0/0"]    # Permite tráfico desde cualquier dirección IP.
  }

  # Reglas de ingreso para permitir tráfico HTTPS.
  ingress {
    description      = "Permitir trafico HTTPS"
    from_port        = 443              # Puerto de entrada (HTTPS).
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]    # Permite tráfico desde cualquier dirección IP.
  }

  # Reglas de ingreso para permitir acceso SSH.
  ingress {
    description      = "Permitir acceso SSH"
    from_port        = 22               # Puerto de entrada (SSH).
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]    # Permite acceso desde cualquier dirección IP (debe ser restringido en entornos reales).
  }

  # Reglas de egreso para permitir todo el tráfico saliente.
  egress {
    from_port   = 0                     # Puerto de salida (todos).
    to_port     = 0
    protocol    = "-1"                  # Permite todos los protocolos.
    cidr_blocks = ["0.0.0.0/0"]         # Permite tráfico hacia cualquier dirección IP.
  }
}

####################################################################################################
# CONFIGURACIÓN DE LA INSTANCIA EC2
####################################################################################################
# Este recurso lanza una instancia EC2 usando la AMI recuperada en el bloque anterior.
# Asocia el grupo de seguridad a la instancia EC2 y configura la conexión SSH.

resource "aws_instance" "web_server" {
  ami                   = data.aws_ami.latest_ami.id # Usa la AMI más reciente creada con Packer.
  instance_type         = var.instance_type          # Define el tipo de instancia basado en la variable `instance_type`.
  key_name              = var.key_name               # Especifica la clave SSH para acceso remoto.
  #vpc_security_group_ids = [aws_security_group.web_server_sg.id] # Asocia el grupo de seguridad configurado.
  # Referencia correcta al grupo de seguridad configurado.
  vpc_security_group_ids = length(aws_security_group.web_server_sg) > 0 ? [aws_security_group.web_server_sg[0].id] : [data.aws_security_group.existing_sg.id]

  tags = {
    Name = var.instance_name # Etiqueta la instancia con el nombre especificado en la variable.
  }

  # Configuración para conectar a la instancia vía SSH.
  connection {
    type        = "ssh"
    user        = "ubuntu"                    # Usuario predeterminado en las AMIs de Ubuntu.
    private_key = file("C:\\Users\\User\\.aws\\unir.pem") # Ruta a la clave privada para la conexión SSH. (cuando cree el par de claves lo almacene en esta direccion)
    host        = self.public_ip              # Usa la IP pública de la instancia como host.
  }

  # Provisionador remoto para ejecutar comandos en la instancia EC2.
  provisioner "remote-exec" {
    inline = [
      "echo 'La instancia está configurada correctamente.'" # Muestra un mensaje simple para verificar que la instancia está configurada.
    ]
  }
}

####################################################################################################
# SALIDA DE INFORMACIÓN
####################################################################################################
# Estos bloques definen las salidas que se mostrarán al usuario al finalizar el despliegue.
# Se incluye el ID de la instancia y su dirección IP pública.
output "instance_id" {
  value = aws_instance.web_server.id # Muestra el ID único de la instancia creada.
}

output "public_ip" {
  value = aws_instance.web_server.public_ip # Muestra la dirección IP pública de la instancia creada.
}

####################################################################################################
####################################################################################################
# DESPLEGAR TERRAFORM
# terraform init --> Inicializa el directorio de trabajo
# terraform plan -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token" --> Muestra los cambios que se realizarán
# terraform apply -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token"--> Aplica los cambios y despliega la infraestructura
# terraform destroy -var "aws_access_key=$env:PKR_VAR_aws_access_key" `  -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" `  -var "aws_session_token=$env:PKR_VAR_aws_session_token" --> Elimina la infraestructura creada


# Get-ChildItem Env: | Where-Object { $_.Name -like "PKR_VAR_*" } --> ver credenciales actuales en la consola de powershell