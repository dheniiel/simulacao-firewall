FROM mysql:8.4
# Scripts executados apenas na PRIMEIRA subida (volume vazio)
COPY init/ /docker-entrypoint-initdb.d/
# Remove CRLF caso os arquivos tenham sido salvos no Windows
RUN sed -i 's/\r$//' /docker-entrypoint-initdb.d/*
