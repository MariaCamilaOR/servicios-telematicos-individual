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

