# Provisioners para instalar y configurar Node.js, Nginx y la aplicación

build {
  name    = "aws-node-nginx"
  sources = ["source.amazon-ebs.aws_builder"]

  provisioner "shell" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y nginx",
      "curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -",
      "sudo apt install -y nodejs build-essential",
      "sudo npm install pm2@latest -g",
      "sudo ufw allow 'Nginx Full'",
      "sudo systemctl enable nginx"
    ]
  }

  provisioner "file" {
    source      = "provisioners/app.js"
    destination = "/home/ubuntu/app.js"
  }

  provisioner "shell" {
    inline = [
      "pm2 start /home/ubuntu/app.js",
      "pm2 save",
      "pm2 startup"
    ]
  }
}
