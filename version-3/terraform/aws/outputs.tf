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