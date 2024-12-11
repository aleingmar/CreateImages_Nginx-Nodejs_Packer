# Este archivo se utiliza para centralizar la configuración de los proveedores que se comparten entre los módulos. 
# Esto permite evitar duplicar la configuración en los módulos de AWS y Azure.

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}