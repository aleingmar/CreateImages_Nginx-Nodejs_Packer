####################################################################################################
# CONFIGURACIÓN DE TERRAFORM PARA LOS PROVEEDORES AWS Y AZURE
####################################################################################################

# AWS Provider
provider "aws" {
  region = var.aws_region
}

# Azure Provider
provider "azurerm" {
  features {}
}



#################################################################################################
#################################################################################################
#################################################################################################
                                            #AWS
####################################################################################################
####################################################################################################
####################################################################################################
# IMPORTANTE --> VARIABLE COUNT
# count es una variable que te dice el numero de recursos a levantar en los tipo RESOURCES--> si es uno levantara 1 y si es 0, pues 0. (si fuese 3 levantaria 3 recursos)
# cuando se usa count, se debe usar el indice para acceder a los recursos, por ejemplo aws_instance.web_server[0].id

# RECURSO PARA EJECUTAR PACKER Y GENERAR LA AMI
# Este recurso utiliza un comando local (en la maquina que ejecuta terraform init) para ejecutar Packer con las variables necesarias
# y generar la AMI basada en el archivo de configuración de Packer (main.pkr.hcl).
resource "null_resource" "packer_ami" {

  count = var.deployment_target == "aws" || var.deployment_target == "both" ? 1 : 0

  # local-exec ejecuta un comando en la máquina que ejecuta Terraform.
  provisioner "local-exec" {
    # Este comando invoca Packer para construir una AMI personalizada usando las variables y configuraciones proporcionadas.
    # usa solo ese provisioner y builder comandos-cloud-node-nginx.amazon-ebs.aws_builder
    command = "packer build -only=comandos-cloud-node-nginx.amazon-ebs.aws_builder -var aws_access_key=${var.aws_access_key} -var aws_secret_key=${var.aws_secret_key} -var aws_session_token=${var.aws_session_token} -var-file=..\\packer\\variables.pkrvars.hcl ..\\packer\\main.pkr.hcl"
  }
}

####################################################################################################
# OBTENER LA ÚLTIMA AMI CREADA
####################################################################################################
data "aws_ami" "latest_ami" {
  count = var.deployment_target == "aws" || var.deployment_target == "both" ? 1 : 0
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
  count = var.deployment_target == "aws" || var.deployment_target == "both" ? 1 : 0
  default = true # Recupera la VPC predeterminada asociada a la cuenta AWS.
}

####################################################################################################
# CONFIGURACIÓN DEL GRUPO DE SEGURIDAD PARA LA INSTANCIA EC2
####################################################################################################
# Intentar buscar un grupo de seguridad existente basado en su nombre y VPC.
# data "aws_security_group" "existing_sg" {
#   count = var.deployment_target == "aws" || var.deployment_target == "both" ? 1 : 0
#   # Filtro para buscar un grupo de seguridad por su nombre.
#   filter {
#     name   = "group-name"
#     values = ["${var.instance_name}-sg"] # Nombre basado en la variable `instance_name`.
#   }
#   # Filtro para asegurarse de que pertenece a la VPC predeterminada.
#   # filter {
#   #   name   = "vpc-id"
#   #   values = [data.aws_vpc.default[0].id] # ID de la VPC predeterminada.
#   # }
#   filter {
#     name   = "vpc-id"
#     values = length(data.aws_vpc.default) > 0 ? [data.aws_vpc.default[0].id] : []
#   }

# }
resource "aws_security_group" "web_server_sg" {
  # Crear un nuevo grupo de seguridad solo si no existe uno con el nombre especificado.
  # Condición para crear o no el recurso. (si no existe count=1, se crea uno nuevo), try es para que no falle si no hay
  count = var.deployment_target == "aws" || var.deployment_target == "both" ? 1 : 0
  #count = length(try(data.aws_security_group.existing_sg, [])) == 0 ? 1 : 0
  name        = "${var.instance_name}-sg" # El nombre del grupo de seguridad se basa en el nombre de la instancia.
  description = "Grupo de seguridad para la instancia EC2" # Descripción del grupo.
  #vpc_id      = data.aws_vpc.default[0].id  # Asocia este grupo de seguridad a la VPC predeterminada.
  vpc_id      = length(data.aws_vpc.default) > 0 ? data.aws_vpc.default[0].id : null
  
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
###################################################
# GENERA EL PAR DE CLAVES Y SE LO PASA A AWS
##################################################
# no almacenamos las claves, no podriamos usarlas para conectarnos por ssh a la instancia 
# Generar un par de claves SSH automáticamente
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Registrar la clave pública en AWS
resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name # Nombre de la clave en AWS
  public_key = tls_private_key.ssh_key.public_key_openssh
}

####################################################################################################
# CONFIGURACIÓN DE LA INSTANCIA EC2
####################################################################################################
# Este recurso lanza una instancia EC2 usando la AMI recuperada en el bloque anterior.
# Asocia el grupo de seguridad a la instancia EC2 y configura la conexión SSH.

resource "aws_instance" "web_server" {
  ## IMPORTANTE--> Condicion para desplegar en AWS, si al hacer el terraform apply el valor del target es aws o both, se desplegara en aws
  count = var.deployment_target == "aws" || var.deployment_target == "both" ? 1 : 0

  ami                   = data.aws_ami.latest_ami[0].id # Usa la AMI más reciente creada con Packer.
  instance_type         = var.instance_type          # Define el tipo de instancia basado en la variable `instance_type`.
  key_name              = aws_key_pair.generated_key.key_name              # Especifica la clave SSH para acceso remoto.
  #vpc_security_group_ids = [aws_security_group.web_server_sg.id] # Asocia el grupo de seguridad configurado.
  # Referencia correcta al grupo de seguridad configurado.
  vpc_security_group_ids = [aws_security_group.web_server_sg[0].id]

  tags = {
    Name = var.instance_name # Etiqueta la instancia con el nombre especificado en la variable.
  }

  # Configuración para conectar a la instancia vía SSH.
  # connection {
  #   type        = "ssh"
  #   user        = "ubuntu"                    # Usuario predeterminado en las AMIs de Ubuntu.
  #   private_key = file("C:\\Users\\User\\.aws\\unir.pem") # Ruta a la clave privada para la conexión SSH. (cuando cree el par de claves lo almacene en esta direccion)
  #   host        = self.public_ip              # Usa la IP pública de la instancia como host.
  # }
  # Configuración para conectar a la instancia vía SSH.
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ssh_key.private_key_pem
    host        = self.public_ip
  }

  # Provisionador remoto para ejecutar comandos en la instancia EC2.
  provisioner "remote-exec" {
    inline = [
      "echo 'La instancia está configurada correctamente.'" # Muestra un mensaje simple para verificar que la instancia está configurada.
    ]
  }
}

####################################################################################################
####################################################################################################
####################################################################################################
                                            #AZURE
####################################################################################################
####################################################################################################
####################################################################################################

####################################################################################################
# CONFIGURACIÓN DEL GRUPO DE RECURSOS PARA LA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
# Crea un grupo de recursos donde se alojarán los recursos de Azure, como redes y máquinas virtuales.
resource "azurerm_resource_group" "example_rg" {

  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  #name     = "${var.instance_name}-rg" # El nombre del grupo de recursos se basa en la variable `instance_name`.
  name = var.azure_resource_group_name
  location = var.azure_region          # Define la región donde se desplegarán los recursos.
}

####################################################################################################
# CONFIGURACIÓN PARA EJECUTAR PACKER Y GENERAR LA IMAGEN EN AZURE
####################################################################################################
# Este recurso utiliza un comando local (en la máquina que ejecuta `terraform init`) para ejecutar Packer con las variables necesarias
# y generar la imagen basada en el archivo de configuración de Packer (`main.pkr.hcl`).
resource "null_resource" "packer_ami_azure" {

  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  depends_on = [azurerm_resource_group.example_rg] # Espera a que el recurso `azurerm_resource_group.example_rg` termine --> asegura que el grupo de recursos esté creado antes de intentar crear la imagen.
  # local-exec ejecuta un comando en la máquina que ejecuta Terraform.
  provisioner "local-exec" {
    # Este comando invoca Packer para construir una imagen personalizada usando las variables y configuraciones proporcionadas.
    command = "packer build -only=ansible-cloud-node-nginx.azure-arm.azure_builder -var azure_subscription_id=${var.azure_subscription_id} -var azure_client_id=${var.azure_client_id} -var azure_client_secret=${var.azure_client_secret} -var azure_tenant_id=${var.azure_tenant_id} -var-file=../packer/variables.pkrvars.hcl ../packer/main.pkr.hcl"
  }
}

####################################################################################################
# OBTENER LA ÚLTIMA IMAGEN CREADA EN AZURE
####################################################################################################
data "azurerm_image" "latest_azure_image" {

  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0

  depends_on          = [null_resource.packer_ami_azure] # Espera a que el provisioner `packer_ami_azure` termine --> asegura que la imagen sea creada antes de intentar recuperarla.
  name                = var.azure_image_name    # Busca la imagen por el nombre especificado en las variables.
  #resource_group_name = "${var.instance_name}-rg" # Especifica el grupo de recursos donde está ubicada la imagen.
  resource_group_name = var.azure_resource_group_name
}

####################################################################################################
# CONFIGURACIÓN DE LA RED VIRTUAL PARA LA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
# Configura una red virtual para conectar recursos como la máquina virtual y la interfaz de red.
resource "azurerm_virtual_network" "example_vnet" {

  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  name                = "${var.azure_instance_name}-vnet"  # Nombre de la red virtual basado en `instance_name`.
  address_space       = ["10.0.0.0/16"]              # Espacio de direcciones IP asignado a la red.
  location            = azurerm_resource_group.example_rg[0].location # Ubicación de la red virtual (mismo lugar que el grupo de recursos).
  resource_group_name = azurerm_resource_group.example_rg[0].name     # Grupo de recursos asociado.
}

####################################################################################################
# CONFIGURACIÓN DE GRUPO DE SEGURIDAD PARA LA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
resource "azurerm_network_security_group" "example_nsg" {
  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  name                = "${var.azure_instance_name}-nsg"
  location            = azurerm_resource_group.example_rg[0].location
  resource_group_name = azurerm_resource_group.example_rg[0].name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


####################################################################################################
# CONFIGURACIÓN DE LA SUBRED PARA LA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
# Configura una subred dentro de la red virtual para conectar la máquina virtual.
resource "azurerm_subnet" "example_subnet" {

  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  name                 = "${var.azure_instance_name}-subnet"  # Nombre de la subred basado en `instance_name`.
  resource_group_name  = azurerm_resource_group.example_rg[0].name # Grupo de recursos asociado.
  virtual_network_name = azurerm_virtual_network.example_vnet[0].name # Nombre de la red virtual a la que pertenece esta subred.
  address_prefixes     = ["10.0.1.0/24"]                # Rango de direcciones IP asignado a esta subred.
  
}
# Configura una IP pública para la máquina virtual en Azure.
# resource "azurerm_public_ip" "example_public_ip" {
#   count               = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
#   name                = "${var.azure_instance_name}-public-ip"
#   location            = azurerm_resource_group.example_rg[0].location
#   resource_group_name = azurerm_resource_group.example_rg[0].name
#   allocation_method   = "Dynamic" # Usa una IP pública dinámica
# }
resource "azurerm_public_ip" "example_public_ip" {
  count               = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  name                = "${var.azure_instance_name}-public-ip"
  location            = azurerm_resource_group.example_rg[0].location
  resource_group_name = azurerm_resource_group.example_rg[0].name
  allocation_method   = "Static" # Cambia de Dynamic a Static
  sku                 = "Standard" # Mantén el SKU Standard si lo estás utilizando
}

####################################################################################################
# CONFIGURACIÓN DE LA INTERFAZ DE RED PARA LA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
# Configura una interfaz de red para conectar la máquina virtual a la red y asignar una dirección IP dinámica.
resource "azurerm_network_interface" "example_nic" {

  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0
  name                = "${var.azure_instance_name}-nic"       # Nombre de la interfaz de red basado en `instance_name`.
  location            = azurerm_resource_group.example_rg[0].location # Ubicación de la interfaz de red (mismo lugar que el grupo de recursos).
  resource_group_name = azurerm_resource_group.example_rg[0].name      # Grupo de recursos asociado.
  
  ip_configuration {
    name                          = "internal"           # Nombre del perfil de configuración IP.
    subnet_id                     = azurerm_subnet.example_subnet[0].id # Subred a la que pertenece esta interfaz.
    private_ip_address_allocation = "Dynamic"            # Asigna dinámicamente una dirección IP privada.
    public_ip_address_id          = azurerm_public_ip.example_public_ip[0].id # Asocia la IP pública aquí
  }
  
}
# Asocia la interfaz de red con el grupo de seguridad de red.
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.example_nic[0].id
  network_security_group_id = azurerm_network_security_group.example_nsg[0].id
}


####################################################################################################
# CONFIGURACIÓN DE LA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
# Este recurso lanza una máquina virtual usando la imagen recuperada en el bloque anterior.
# Asocia la interfaz de red y configura los discos y el perfil del sistema operativo.

resource "azurerm_virtual_machine" "example_vm" {

  ## IMPORTANTE--> Condicion para desplegar en AZURE, si al hacer el terraform apply el valor del target es azure o both, se desplegara en azure
  count = var.deployment_target == "azure" || var.deployment_target == "both" ? 1 : 0

  name                  = "${var.azure_instance_name}-vm" # Nombre de la máquina virtual basado en `instance_name`.
  location              = azurerm_resource_group.example_rg[0].location # Ubicación de la máquina virtual (mismo lugar que el grupo de recursos).
  resource_group_name   = azurerm_resource_group.example_rg[0].name      # Grupo de recursos asociado.
  network_interface_ids = [azurerm_network_interface.example_nic[0].id] # Asocia la interfaz de red configurada previamente.
  vm_size               = var.azure_instance_type                    # Tipo de máquina virtual basado en la variable `azure_instance_type`.

  # Configuración del disco del sistema operativo.
  storage_os_disk {
    name              = "${var.azure_instance_name}-osdisk"  # Nombre del disco del sistema operativo basado en `instance_name`.
    caching           = "ReadWrite"                   # Configuración de caché para el disco.
    create_option     = "FromImage"                   # Indica que el disco se crea a partir de una imagen existente.
    managed_disk_type = "Standard_LRS"                # Tipo de disco administrado.
  }

  # Configuración para usar la imagen personalizada generada con Packer.
  storage_image_reference {
    id = data.azurerm_image.latest_azure_image[0].id     # Utiliza la imagen recuperada en el bloque `data.azurerm_image`.
  }
  ################## CONFIGURACION PARA ACCEDER POR CONTRASEÑA EN VEZ DE USAR PAR DE CLAVES (recomendado pero mas lio)
  # Configuración del perfil del sistema operativo.
  os_profile {
    computer_name  = "${var.azure_instance_name}"          # Nombre del equipo (máquina virtual).
    admin_username = var.azure_admin_username       # Usuario administrador para la conexión.
    admin_password = var.azure_admin_password       # Contraseña para el usuario administrador.
  }

  # Configuración adicional para sistemas operativos Linux.
  os_profile_linux_config {
    disable_password_authentication = false         # Permite autenticación con contraseña.
  }

  # Provisioner para ejecutar comandos en la VM
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = azurerm_public_ip.example_public_ip[0].ip_address
      user        = var.azure_admin_username
      password    = var.azure_admin_password
    }

    inline = [
      # Ejecuta app.js (trampilla un poco no he conseguido hacerlo directamente con la plantilla)
      "pm2 start /home/ubuntu/app.js"
    ]
  }
}

####################################################################################################
# SALIDA DE INFORMACIÓN
####################################################################################################
# Estos bloques definen las salidas que se mostrarán al usuario al finalizar el despliegue.
# Se incluye el ID de la instancia y su dirección IP pública.

output "aws_instance_id" {
  value = length(aws_instance.web_server) > 0 ? aws_instance.web_server[0].id : null
  description = "ID de la instancia en AWS si existe"
}

output "aws_public_ip" {
  value = length(aws_instance.web_server) > 0 ? aws_instance.web_server[0].public_ip : null
  description = "IP pública de la instancia en AWS si existe"
}

output "azure_vm_id" {
  value       = length(azurerm_virtual_machine.example_vm) > 0 ? azurerm_virtual_machine.example_vm[0].id : null
  description = "ID de la máquina virtual en Azure si existe"
}

output "azure_vm_ip" {
  value       = length(azurerm_network_interface.example_nic) > 0 ? azurerm_network_interface.example_nic[0].private_ip_address : null
  description = "IP privada de la máquina virtual en Azure si existe"
}

output "azure_public_ip" {
  value = length(azurerm_public_ip.example_public_ip) > 0 ? azurerm_public_ip.example_public_ip[0].ip_address : null
  description = "IP pública de la máquina virtual en Azure si existe"
}




####################################################################################################

# DESPLEGAR TERRAFORM

# Get-ChildItem Env: | Where-Object { $_.Name -like "PKR_VAR_*" } --> ver credenciales actuales de AWS en la consola de powershell
# Get-ChildItem Env: | Where-Object { $_.Name -like "ARM_*" } --> ver credenciales actuales DE AZURE en la consola de powershell

######## EL BUENO
# terraform init --> Inicializa el directorio de trabajo
# terraform apply -var "deployment_target=both" ` -var "aws_access_key=$env:PKR_VAR_aws_access_key" ` -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" ` -var "aws_session_token=$env:PKR_VAR_aws_session_token" ` -var "azure_subscription_id=$env:ARM_SUBSCRIPTION_ID" ` -var "azure_client_id=$env:ARM_CLIENT_ID" ` -var "azure_client_secret=$env:ARM_CLIENT_SECRET" ` -var "azure_tenant_id=$env:ARM_TENANT_ID"
# terraform destroy -var "deployment_target=aws" ` -var "aws_access_key=$env:PKR_VAR_aws_access_key" ` -var "aws_secret_key=$env:PKR_VAR_aws_secret_key" ` -var "aws_session_token=$env:PKR_VAR_aws_session_token" ` -var "azure_subscription_id=$env:ARM_SUBSCRIPTION_ID" ` -var "azure_client_id=$env:ARM_CLIENT_ID" ` -var "azure_client_secret=$env:ARM_CLIENT_SECRET" ` -var "azure_tenant_id=$env:ARM_TENANT_ID"