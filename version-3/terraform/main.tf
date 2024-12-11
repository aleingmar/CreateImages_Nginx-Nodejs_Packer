module "aws" {
  source = "./aws"

  aws_region     = var.aws_region
  ami_name       = var.aws_ami_name
  instance_type  = var.aws_instance_type
  key_name       = var.aws_key_name
  instance_name  = var.aws_instance_name
}

module "azure" {
  source = "./azure"

  azure_location          = var.azure_location
  resource_group_name     = var.resource_group_name
  azure_client_id         = var.azure_client_id
  azure_client_secret     = var.azure_client_secret
  azure_subscription_id   = var.azure_subscription_id
  azure_tenant_id         = var.azure_tenant_id
  azure_vm_size           = var.azure_vm_size
  azure_ami_name          = var.azure_ami_name
}

output "aws_public_ip" {
  value = module.aws.public_ip
}

output "azure_public_ip" {
  value = module.azure.public_ip
}