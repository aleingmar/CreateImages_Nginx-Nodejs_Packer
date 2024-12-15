### Variables de Packer
ami_name          = "IMAGEN_Node_Nginx"
instance_type     = "t2.micro"
project_name      = "Actividad Packer"
environment       = "dev"

# AWS
aws_region        = "us-east-1"

# Azure
azure_region          = "East US"
azure_instance_type   = "Standard_B1ls"
azure_admin_username  = "adminuser"
azure_admin_password  = "P@ssw0rd123"
azure_image_name      = "custom-azure-image"
azure_resource_group_name  = "packer-images"