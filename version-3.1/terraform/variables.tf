### Variable para elegir en que nube quiero desplegar

variable "deployment_target" {
  description = "Define qué infraestructura desplegar: aws, azure o both"
  default     = "both"
}


############################################
# AWS
######º#####################################


variable "aws_region" {
  default     = "us-east-1"
  description = "Región de AWS"
}

variable "ami_name" {
  default     = "mi-ami"
  description = "Nombre base de la AMI"
}

variable "instance_type" {
  default     = "t2.micro"
  description = "Tipo de instancia EC2"
}

variable "key_name" {
  description = "Nombre del par de claves para acceder a la instancia"
}

variable "instance_name" {
  default     = "mi-instancia-ec2"
  description = "Nombre de la instancia"
}
### CREDENCIALES

variable "aws_access_key" {
  description = "Clave de acceso de AWS"
}

variable "aws_secret_key" {
  description = "Clave secreta de AWS"
}

variable "aws_session_token" {
  description = "Token de sesión de AWS"
}

############################################
# AZURE
######º#####################################

###############CREDENCIALES
variable "azure_subscription_id" { description = "Azure subscription ID" }
variable "azure_client_id" { description = "Azure client ID" }
variable "azure_client_secret" { description = "Azure client secret" }
variable "azure_tenant_id" { description = "Azure tenant ID" }
###############################

variable "azure_region" { 
  default = "East US" 
  description = "Azure region" 
}
variable "azure_instance_type" { 
  default = "Standard_B1ms" 
  description = "Azure instance type" 
  }
variable "azure_admin_username" { 
  default = "adminuser" 
  description = "Admin username for Azure VM" 
}
variable "azure_admin_password" { description = "Admin password for Azure VM" }
variable "azure_image_name" { description = "Name of the Azure image created by Packer" }
variable "azure_resource_group_name" { description = "Name of the Azure resource group" }
variable "azure_instance_name" { description = "Name of the Azure instance" }

