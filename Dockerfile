FROM postgis/postgis:15-3.4-alpine

# Установка полного набора локалей
RUN apk add --no-cache lang

# Настройка локали по умолчанию
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

COPY init.sql /docker-entrypoint-initdb.d/