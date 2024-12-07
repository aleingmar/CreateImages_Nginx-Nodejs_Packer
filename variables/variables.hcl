# Archivo de variables para configuración de AWS y parámetros generales.

variable "aws_access_key" {
  description = "Clave de acceso de AWS"
  default     = ""
}

variable "aws_secret_key" {
  description = "Clave secreta de AWS"
  default     = ""
}

variable "aws_session_token" {
  default = ""
}

variable "aws_region" {
  description = "Región en la que se desplegarán los recursos"
  default     = "us-east-1"
}

variable "ami_name" {
  description = "Nombre de la AMI generada por Packer"
  default     = "Actividad_Node_Nginx_AMI"
}

variable "instance_type" {
  description = "Tipo de instancia de AWS"
  default     = "t2.micro"
}

variable "project_name" {
  description = "Nombre del proyecto"
  default     = "Actividad Packer AWS"
}

variable "environment" {
  description = "Entorno del proyecto (dev, test, prod)"
  default     = "dev"
}