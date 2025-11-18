## 1. Empaquetado y despliegue local con Docker

### 1.1. Clonar repositorio (en PowerShell)

```bash
git clone https://github.com/omondragon/MiniWebApp.git
cd MiniWebApp
vagrant up
vagrant ssh servidorWeb
```

### 1.2. Instalar Docker

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

sudo apt-get update

sudo apt-get install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

exit

vagrant ssh servidorWeb

sudo docker run hello-world

sudo docker info | more
```

### 1.3. Configurar aplicación web

```bash
cd /home/vagrant/webapp
mkdir -p certs apache

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout certs/webapp.key -out certs/webapp.crt -subj "/C=ES/ST=Madrid/L=Madrid/O=WebApp/OU=Dev/CN=localhost"

cat <<'EOF' > requirements.txt
Flask==2.3.3
flask-cors
Flask-MySQLdb
Flask-SQLAlchemy
EOF
cat <<'EOF' > Dockerfile
FROM python:3.10-slim
RUN apt-get update && apt-get install -y \
    default-libmysqlclient-dev build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
ENV FLASK_APP=run.py \
    FLASK_ENV=production \
    PYTHONUNBUFFERED=1
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
EOF
cat <<'EOF' > docker-compose.yml
services:
  mysql:
    image: mysql:8.0
    container_name: mysql_db
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: myflaskapp
    volumes:
      - mysql_data:/var/lib/mysql
      - /home/vagrant/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "3306:3306"
    networks:
      - app_network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-proot"]
      interval: 10s
      timeout: 5s
      retries: 5

  webapp:
    build: .
    container_name: miniwebapp
    expose:
      - "5000"
    environment:
      - FLASK_APP=run.py
      - FLASK_ENV=production
      - MYSQL_HOST=mysql
      - MYSQL_USER=root
      - MYSQL_PASSWORD=root
      - MYSQL_DB=myflaskapp
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - app_network
    restart: unless-stopped

  apache:
    build:
      context: /home/vagrant/webapp/apache
    container_name: web_apache_proxy
    depends_on:
      - webapp
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /home/vagrant/webapp/certs:/etc/apache2/ssl:ro
    networks:
      - app_network
    restart: unless-stopped

networks:
  app_network:
    driver: bridge

volumes:
  mysql_data:
EOF
cat <<'EOF' > apache/Dockerfile
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN a2enmod ssl proxy proxy_http headers rewrite
COPY miniwebapp.conf /etc/apache2/sites-available/miniwebapp.conf
RUN a2ensite miniwebapp.conf && a2dissite 000-default.conf
CMD ["/usr/sbin/apachectl", "-D", "FOREGROUND"]
EOF
cat <<'EOF' > apache/miniwebapp.conf
<VirtualHost *:80>
    ServerName localhost
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^/(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName localhost

    SSLEngine on
    SSLCertificateFile    /etc/apache2/ssl/webapp.crt
    SSLCertificateKeyFile /etc/apache2/ssl/webapp.key

    ProxyPreserveHost On
    ProxyPass        / http://webapp:5000/
    ProxyPassReverse / http://webapp:5000/

    Header always set Strict-Transport-Security "max-age=31536000"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set X-XSS-Protection "1; mode=block"
</VirtualHost>
</IfModule>
EOF
docker compose up -d --build
docker compose ps
curl -I http://localhost
curl -kI https://localhost
```

## 2. Despliegue en la nube con AWS EC2

### 2.1. Conectarse a EC2

```bash
ssh -i "testssh.pem" ubuntu@ec2-98-89-43-135.compute-1.amazonaws.com
```

### 2.2. Instalar Docker en EC2

```bash
sudo apt-get update

sudo apt-get install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker ubuntu


newgrp docker

sudo docker run hello-world
```

### 2.3. Subir archivos a EC2 usando Git

```bash
# En tu máquina local (Vagrant o donde tengas los archivos)
cd /home/vagrant/entregables/archivos-configurados-punto1
git init
git add .
git commit -m "Proyecto CloudNova - Docker, Prometheus, Grafana"
git branch -M main
git remote add origin https://github.com/MariaCamilaOR/servicios-telematicos-individual.git

git push -u origin main
```

Cuando te pida credenciales:
- Username: MariaCamilaOR
- Password: ghp_anpS....

```bash
# En EC2, clonar el repositorio
cd ~

git clone https://github.com/MariaCamilaOR/servicios-telematicos-individual.git

cd servicios-telematicos-individual
```

**Nota:** Los archivos del proyecto CloudNova están en la raíz del repositorio (docker-compose.yml, Dockerfile, etc.)

### 2.4. Configurar proyecto en EC2

```bash
cd ~/servicios-telematicos-individual
mkdir -p certs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout certs/webapp.key -out certs/webapp.crt -subj "/C=ES/ST=Madrid/L=Madrid/O=WebApp/OU=Dev/CN=98.89.43.135"

```

### 2.5. Ejecutar aplicación en EC2

```bash
cd ~/servicios-telematicos-individual
docker compose up -d --build
docker compose ps
curl -I http://localhost
curl -kI https://localhost
```

### 2.6. Verificar acceso remoto

```
http://98.89.43.135
https://98.89.43.135
```

## 3. Monitoreo con Prometheus y Node Exporter

### 3.1. Instalar Prometheus

```bash
sudo apt update

sudo groupadd --system prometheus

sudo useradd -s /sbin/nologin --system -g prometheus prometheus

sudo mkdir /etc/prometheus

sudo mkdir /var/lib/prometheus

cd /home/vagrant/punto3

wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz

tar vxf prometheus*.tar.gz


cd prometheus-2.43.0.linux-amd64

sudo mv prometheus /usr/local/bin

sudo mv promtool /usr/local/bin

sudo chown prometheus:prometheus /usr/local/bin/prometheus

sudo chown prometheus:prometheus /usr/local/bin/promtool

sudo mv consoles /etc/prometheus

sudo mv console_libraries /etc/prometheus

sudo mv prometheus.yml /etc/prometheus

sudo chown prometheus:prometheus /etc/prometheus

sudo chown -R prometheus:prometheus /etc/prometheus/consoles

sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries

sudo chown -R prometheus:prometheus /var/lib/prometheus

sudo nano /etc/systemd/system/prometheus.service
```

Pegar:
```
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090


[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
sudo ufw allow 9090/tcp
curl http://localhost:9090
curl http://192.168.60.3:9090
```

### 3.2. Instalar Node Exporter

```bash
cd /home/vagrant/punto3

wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz

tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz

cd node_exporter-1.6.1.linux-amd64
sudo mv node_exporter /usr/local/bin
sudo chown prometheus:prometheus /usr/local/bin/node_exporter
sudo nano /etc/systemd/system/node_exporter.service
```

Pegar:
```
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
curl http://localhost:9100/metrics
curl http://localhost:9100/metrics | grep "node_"
curl http://192.168.60.3:9100/metrics
curl http://192.168.60.3:9100/metrics | grep "node_"
sudo ufw allow 9100/tcp
```

### 3.3. Configurar prometheus.yml

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Pegar:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
```

```bash
sudo systemctl restart prometheus
sudo systemctl status prometheus
```

### 3.4. Configurar alertas

```bash
sudo mkdir /etc/prometheus/alerts
sudo chown prometheus:prometheus /etc/prometheus/alerts
sudo nano /etc/prometheus/alerts/alerts.yml
```

Pegar:
```yaml
groups:
  - name: system_alerts
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80

        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de CPU"
          description: "El uso de CPU está por encima del 80% durante más de 5 minutos"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80

        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de memoria"
          description: "El uso de memoria está por encima del 80% durante más de 5 minutos"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 20

        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Espacio en disco bajo"
          description: "El espacio disponible en disco está por debajo del 20%"
```

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Pegar:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/alerts/alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
```

```bash
sudo systemctl restart prometheus
sudo systemctl status prometheus
```

### 3.5. Verificar servicios

```bash
sudo systemctl status prometheus
sudo systemctl status node_exporter
curl http://localhost:9100/metrics | grep "node_cpu"
curl http://localhost:9100/metrics | grep "node_memory"
curl http://localhost:9100/metrics | grep "node_filesystem"
curl http://192.168.60.3:9100/metrics | grep "node_cpu"
curl http://192.168.60.3:9100/metrics | grep "node_memory"
curl http://192.168.60.3:9100/metrics | grep "node_filesystem"
```

### 3.6. Acceso a Prometheus

```
http://localhost:9090
http://192.168.60.3:9090
http://localhost:9090/alerts
http://192.168.60.3:9090/alerts
```

### 3.7. Usar la interfaz web de Prometheus

1. Abre tu navegador
2. Ve a: `http://192.168.60.3:9090`
3. En el menú superior, haz clic en **"Status"** → **"Targets"**
4. Verifica que ambos targets estén en estado **UP**
5. En el menú superior, haz clic en **"Graph"**
6. Ejecuta consultas:
   - `node_cpu_seconds_total`
   - `100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - `node_memory_MemAvailable_bytes / 1024 / 1024 / 1024`
   - `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
   - `node_filesystem_avail_bytes{mountpoint="/"} / 1024 / 1024 / 1024`
   - `(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100`
7. En el menú superior, haz clic en **"Alerts"** para ver las alertas configuradas

## 4. Visualización con Grafana

### 4.1. Instalar Grafana

```bash
sudo apt-get install -y software-properties-common

sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

sudo apt-get update

sudo apt-get install -y grafana
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```

### 4.2. Configurar Grafana - Conectar a Prometheus

1. Abre el navegador y ve a: `http://192.168.60.3:3000`
2. Inicia sesión con:
   - Usuario: `admin`
   - Contraseña: `admin`
3. Haz clic en **"Skip"** cuando te pida cambiar la contraseña
4. En el menú lateral izquierdo, haz clic en el icono de **configuración** (⚙️)
5. Haz clic en **"Connections"** y **"view configure data sources"**
6. Haz clic en **"Add data source"**
7. Selecciona **"Prometheus"**
8. En **"URL"**, escribe: `http://localhost:9090`
9. Haz clic en **"Save & test"**
10. Debe aparecer un mensaje verde: **"Data source is working"**

### 4.3. Crear Dashboard con paneles de CPU/Memoria y Gauge de Disco

1. En el menú lateral izquierdo, haz clic en el icono **"+"** (Create)
2. Haz clic en **"Dashboard"**
3. Haz clic en **"Add visualization"**
4. Selecciona **"Prometheus"** como fuente de datos
5. En el campo **"Metrics browser"**, escribe:
   ```
   100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```
6. En la parte superior derecha, cambia el panel type a **"Time series"**
7. Haz clic en **"Apply"**
8. Haz clic en el icono de **lápiz** (Edit) en la parte superior del panel
9. En **"Panel title"**, escribe: `Uso de CPU (%)`
10. Haz clic en **"Apply"**
11. Haz clic en **"Add visualization"**
12. En el campo **"Metrics browser"**, escribe:
    ```
    (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
    ```
13. Cambia el panel type a **"Time series"**
14. Haz clic en **"Apply"**
15. Edita el panel y cambia el título a: `Uso de Memoria (%)`
16. Haz clic en **"Add visualization"**
17. En el campo **"Metrics browser"**, escribe:
    ```
    (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
    ```
18. Cambia el panel type a **"Gauge"**
19. Haz clic en **"Apply"**
20. Edita el panel y cambia el título a: `Espacio Disponible en Disco (%)`
21. En la parte superior derecha, haz clic en **"Save dashboard"** (icono de disco)
22. Escribe un nombre: `Sistema Linux - Monitoreo`
23. Haz clic en **"Save"**

### 4.4. Importar panel preconfigurado desde la biblioteca de Grafana

1. En el menú lateral izquierdo, haz clic en el icono **"+"** (Create)
2. Haz clic en **"Import"**
3. En el campo **"Import via grafana.com"**, escribe el ID: `1860`
4. Haz clic en **"Load"**
5. Selecciona **"Prometheus"** como fuente de datos
6. Haz clic en **"Import"**
7. Verás el dashboard **"Node Exporter Full"** con múltiples paneles
8. Haz clic en **"Save dashboard"** (icono de disco) en la parte superior
9. Escribe un nombre: `Node Exporter Full - Importado`
10. Haz clic en **"Save"**

### 4.5. Verificar funcionamiento de Grafana

```bash
curl http://localhost:3000
curl http://192.168.60.3:3000
sudo systemctl status grafana-server
```

### 4.6. Acceso a Grafana

```
http://192.168.60.3:3000
Usuario: admin
Contraseña: admin
```
