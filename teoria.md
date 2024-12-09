Source: Especifica el proveedor y la imagen base.
Build: Describe cómo se construirá la imagen.
Provisioners: Aquí agregarás los scripts para instalar y configurar Node.js y Nginx.

### ARCHIVOS GENERADOS POR PACKER
- El .vbox es el "manual de instrucciones" para que el proveedor (aws, virtualbox...) entienda que mv debe de levantar.
- El .vdi es el "contenido real" del disco duro, es decir, ahí esta todo el contenido de la ISO base, el codigo fuente de una aplicacion que esta dentro de la imagen por ejemplo... .



### Cómo Funciona Packer con VirtualBox
- Packer controla VirtualBox directamente:
Packer utiliza la API de VirtualBox para crear, configurar y gestionar la máquina virtual.
No necesitas abrir la aplicación gráfica de VirtualBox porque todo se realiza en segundo plano.

- Creación Automática de la VM:
Cuando ejecutas packer build, Packer inicia una instancia de VirtualBox, crea la máquina virtual, y realiza el provisioning automáticamente.

### ¿Qué se espera después de ejecutar Packer con un builder de AWS?
En tu caso, se crea una AMI basada en los pasos de configuración definidos en la plantilla de Packer. Una AMI es una imagen de máquina que incluye:

El sistema operativo (en tu caso, Ubuntu 20.04).
Todo el software instalado y configurado (Nginx, Node.js, PM2, etc.).
Cualquier personalización que hayas definido en los provisioners de Packer.
La instancia creada durante el proceso es temporal. Packer usa esta instancia para aplicar los provisioners (instalaciones y configuraciones) y luego genera una AMI con el resultado final. Una vez creada la AMI, la instancia es terminada automáticamente.

### NOTAS SUELTAS
- AMI: Amazon machine image 