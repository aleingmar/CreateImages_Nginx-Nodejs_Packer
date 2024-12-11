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

####################################################################################################
# GENERAR AMI EN AWS
####################################################################################################
resource "null_resource" "packer_ami_aws" {
  provisioner "local-exec" {
    command = "packer build -var aws_access_key=${var.aws_access_key} -var aws_secret_key=${var.aws_secret_key} -var aws_session_token=${var.aws_session_token} -var-file=../packer/variables.pkrvars.hcl ../packer/main.pkr.hcl"
  }
}

# Data for AWS AMI
data "aws_ami" "latest_ami" {
  depends_on = [null_resource.packer_ami_aws]
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami_name}*"]
  }
  owners = ["self"]
}

####################################################################################################
# OBTENER LA VPC POR DEFECTO (configuración de red virtual)
####################################################################################################
data "aws_vpc" "default" {
  default = true
}

####################################################################################################
# CONFIGURACIÓN DEL GRUPO DE SEGURIDAD PARA LA INSTANCIA EC2 EN AWS
####################################################################################################
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["${var.instance_name}-sg"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "web_server_sg" {
  count       = try(data.aws_security_group.existing_sg.id != "", false) ? 0 : 1
  name        = "${var.instance_name}-sg"
  description = "Grupo de seguridad para la instancia EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Permitir trafico HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Permitir trafico HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Permitir acceso SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

####################################################################################################
# CONFIGURACIÓN DE LA INSTANCIA EC2 EN AWS
####################################################################################################
resource "aws_instance" "web_server_aws" {
  ami                   = data.aws_ami.latest_ami.id
  instance_type         = var.instance_type
  key_name              = var.key_name
  vpc_security_group_ids = length(aws_security_group.web_server_sg) > 0 ? [aws_security_group.web_server_sg[0].id] : [data.aws_security_group.existing_sg.id]

  tags = {
    Name = "${var.instance_name}-aws"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("C:\\Users\\User\\.aws\\unir.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'La instancia está configurada correctamente.'"
    ]
  }
}

##################################################################################################333
####################################################################################################
####################################################################################################
# CONFIGURACIÓN DE UNA MÁQUINA VIRTUAL EN AZURE
####################################################################################################
resource "azurerm_resource_group" "example_rg" {
  name     = "${var.instance_name}-rg"
  location = var.azure_region
}

resource "azurerm_virtual_network" "example_vnet" {
  name                = "${var.instance_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
}

resource "azurerm_subnet" "example_subnet" {
  name                 = "${var.instance_name}-subnet"
  resource_group_name  = azurerm_resource_group.example_rg.name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "example_nic" {
  name                = "${var.instance_name}-nic"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "example_vm" {
  name                  = "${var.instance_name}-vm"
  location              = azurerm_resource_group.example_rg.location
  resource_group_name   = azurerm_resource_group.example_rg.name
  network_interface_ids = [azurerm_network_interface.example_nic.id]
  vm_size               = var.azure_instance_type

  storage_os_disk {
    name              = "${var.instance_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # Use the Packer-created image
  storage_image_reference {
    id = "/subscriptions/${var.azure_subscription_id}/resourceGroups/packer-images/providers/Microsoft.Compute/images/${var.azure_image_name}"
  }

  os_profile {
    computer_name  = "${var.instance_name}"
    admin_username = var.azure_admin_username
    admin_password = var.azure_admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

####################################################################################################
# SALIDA DE INFORMACIÓN
####################################################################################################
output "aws_instance_id" {
  value = aws_instance.web_server_aws.id
}

output "aws_public_ip" {
  value = aws_instance.web_server_aws.public_ip
}

output "azure_vm_id" {
  value = azurerm_virtual_machine.example_vm.id
}

output "azure_vm_ip" {
  value = azurerm_network_interface.example_nic.private_ip_address
}