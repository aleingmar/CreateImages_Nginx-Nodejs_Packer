######## VARIABLES AWS ########
aws_region      = "us-east-1"
aws_ami_name    = "Actividad_Node_Nginx_AMI_9"
aws_instance_type = "t2.micro"
aws_key_name    = "unir" # Nombre del par de claves para acceder a la instancia
aws_instance_name = "Instance_Node_Nginx"
# Credenciales de AWS, las obtiene de las variables de entorno
# aws_access_key = "TU_ACCESS_KEY"
# aws_secret_key = "TU_SECRET_KEY"
# aws_session_token = "TU_SESSION_TOKEN"

######## VARIABLES AZURE ########
azure_location           = "eastus"
resource_group_name      = "my-resource-group"
azure_client_id          = "client-id"
azure_client_secret      = "client-secret"
azure_subscription_id    = "subscription-id"
azure_tenant_id          = "tenant-id"
azure_vm_size            = "Standard_B1s"
azure_ami_name           = "UbuntuLTS"