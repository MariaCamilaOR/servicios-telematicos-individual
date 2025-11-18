FROM python:3.10-slim

# Instalar dependencias de sistema necesarias (por ejemplo para MySQL client)
RUN apt-get update && apt-get install -y \
    default-libmysqlclient-dev build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Directorio de trabajo
WORKDIR /app

# Copiar primero las dependencias de Python
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el código de la aplicación
COPY . .

# Puerto expuesto por Flask
EXPOSE 5000

# Variables de entorno para Flask
ENV FLASK_APP=run.py \
    FLASK_ENV=production \
    PYTHONUNBUFFERED=1

# Arranque con el servidor de desarrollo de Flask (suficiente para este laboratorio)
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]

