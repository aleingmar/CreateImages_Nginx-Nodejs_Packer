aws_region     = "us-east-1"
ami_name       = "Actividad_Node_Nginx_AMI_9"
instance_type  = "t2.micro"
key_name       = "unir" # Nombre del par de claves para acceder a la instancia
instance_name  = "Instance_Node_Nginx"
# Credenciales de AWS, las obtiene de las variables de entorno
# aws_access_key = "TU_ACCESS_KEY"
# aws_secret_key = "TU_SECRET_KEY"
# aws_session_token = "TU_SESSION_TOKEN"

azure_subscription_id = "12345678-1234-1234-1234-123456789abc"
azure_client_id       = "abcdef12-3456-7890-abcd-ef1234567890"
azure_client_secret   = "your-secret-value"
azure_tenant_id       = "12345678-1234-1234-1234-123456789abc"
azure_region          = "East US"
azure_instance_type   = "Standard_B1ms"
azure_admin_username  = "adminuser"
azure_admin_password  = "P@ssw0rd123"
azure_image_name      = "custom-azure-image"