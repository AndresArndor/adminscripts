#!/bin/bash
if [ ! -f './.env' ]; then
  echo 'Can’t find a .env file in this directory'
  exit 1
fi

function get_env {
  grep $1 ./.env | cut -f2 -d "="
}

function get_repo_name {
  echo $1 | awk -F '/' '{print $NF}'
}

function get_port {
  get_env $1 | awk -F ':' '{print $NF}'
}

function get_free_port {
  while :; do
    PORT=$(shuf -i 1024-65535 -n 1)
    LINE=$(lsof -i :$PORT | wc -l)

    if [ $LINE == 0 ]; then
      echo $PORT
      break
    fi
  done
}

PWD=$(pwd)
TMPDIR=$(mktemp -d)
EXEC_LIST=( docker docker-compose mktemp )
REPO_LIST=( $(get_env WEB_REPO) $(get_env API_REPO) )

PORT_WEB=$(get_free_port)
PORT_API=$(get_free_port)
PORT_KEY=$(get_free_port)
PORT_MSP=$(get_free_port)
PORT_SWG=$(get_free_port)

FTP_URL=$(get_env FTP_URL)
FTP_URI=$(echo $FTP_URL | awk -F:// '{print $2}')
FTP_LOGIN=$(echo $FTP_URI | awk -F@ '{print $1}')
FTP_USERNAME=$(echo $FTP_LOGIN | awk -F: '{print $1}')
FTP_PASSWORD=$(echo $FTP_LOGIN | awk -F: '{print $2}')

for i in ${EXEC_LIST[@]}; do
  LINE=$(which $i | wc -l)

  if [ $LINE == 0 ]; then
    echo 'You required install '$i
    exit 1
  fi
done

for i in ${REPO_LIST[@]}; do
  git clone $i $TMPDIR/$(get_repo_name $i)
  cp ./.env $TMPDIR/$(get_repo_name $i)
done

cat << EOF > ./Dockerfile
FROM jboss/keycloak
USER jboss

RUN sed -i -e 's/<web-context>auth<\/web-context>/<web-context>keycloak\/auth<\/web-context>/' \$JBOSS_HOME/standalone/configuration/standalone.xml
RUN sed -i -e 's/<web-context>auth<\/web-context>/<web-context>keycloak\/auth<\/web-context>/' \$JBOSS_HOME/standalone/configuration/standalone-ha.xml
RUN sed -i -e 's/name="\/"/name="\/keycloak\/"/' \$JBOSS_HOME/standalone/configuration/standalone.xml
RUN sed -i -e 's/name="\/"/name="\/keycloak\/"/' \$JBOSS_HOME/standalone/configuration/standalone-ha.xml
RUN sed -i -e 's/\/auth/\/keycloak\/auth"/' \$JBOSS_HOME/welcome-content/index.html
EOF

docker build -t acrarm_keycloak_image - < ./Dockerfile

mkdir -p ./nginx
mkdir -p ./public

PROXY_SET_HEADER=$(cat <<-EOF
    proxy_set_header    Host               $(get_env ORIGIN);
    proxy_set_header    X-Real-IP          \$remote_addr;
    proxy_set_header    X-Forwarded-For    \$proxy_add_x_forwarded_for;
    proxy_set_header    X-Forwarded-Host   \$host;
    proxy_set_header    X-Forwarded-Server \$host;
    proxy_set_header    X-Forwarded-Port   \$server_port;
    proxy_set_header    X-Forwarded-Proto  \$scheme;
EOF)


cat << EOF > ./nginx/nginx.conf
server {
  listen 80;
  server_name $(get_env ORIGIN);
    return 301 https://\$server_name\$request_uri;
#  location /.well-known/acme-challenge {
#    root /var/www/certbot;
#  }
}

server {
  listen 443 ssl;
  server_name $(get_env ORIGIN);
  ssl_certificate /etc/letsencrypt/live/$(get_env ORIGIN)/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$(get_env ORIGIN)/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  location /cdn {
    root /var/public;
  }

  location /keycloak {
    proxy_pass http://172.16.0.1:8180/keycloak;
    $PROXY_SET_HEADER
  }

  location /api {
    proxy_pass http://172.16.0.1:$PORT_API;
    $PROXY_SET_HEADER
  }

  location /swagger {
    proxy_pass http://172.16.0.1:$PORT_SWG;
    $PROXY_SET_HEADER
  }


  location /msp {
    proxy_pass http://172.16.0.1:$PORT_MSP;
    $PROXY_SET_HEADER
  }

  location / {
    proxy_pass http://172.16.0.1:$PORT_WEB;
    $PROXY_SET_HEADER
  }
}
EOF

cat << EOF > $PWD/docker-compose.yml
version: "3.1"
services:
  nginx:
    image: nginx:stable
    command: "/bin/sh -c 'while :; do sleep 6h & wait $${!}; nginx -s reload; done & nginx -g \"daemon off;\"'"
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx:/etc/nginx/conf.d
      - ./public/$(get_env FTP_USERNAME):/var/public/cdn
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    networks:
      - acrarm_default
  certbot:
    image: certbot/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    networks:
      - acrarm_default
  mongo:
    image: mongo
    restart: always
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=$(get_env MONGO_ROOT_USERNAME)
      - MONGO_INITDB_ROOT_PASSWORD=$(get_env MONGO_ROOT_PASSWORD)
    networks:
      - acrarm_default
  keycloak:
    image: acrarm_keycloak_image
    ports:
      - "8180:8080"
    environment:
      - KEYCLOAK_USER=$(get_env KEYCLOAK_ROOT_USERNAME)
      - KEYCLOAK_PASSWORD=$(get_env KEYCLOAK_ROOT_PASSWORD)
      - PROXY_ADDRESS_FORWARDING=true
    networks:
      - acrarm_default
  swagger:
    image: swaggerapi/swagger-ui
    restart: unless-stopped
    ports:
      - "$PORT_SWG:8080"
    volumes:
      - $TMPDIR/$(get_repo_name ${REPO_LIST[1]}):/app
    environment:
      - SWAGGER_JSON=/app/swagger.json
    networks:
      - acrarm_default
  cdn:
    image: fauria/vsftpd
    restart: always
    ports:
      - "21:21"
    volumes:
      - $PWD/public:/home/vsftpd
    environment:
      - FTP_USER=$FTP_USERNAME
      - FTP_PASS=$FTP_PASSWORD
      - PASV_ENABLE=NO
      - LOCAL_UMASK=022
    networks:
      - acrarm_default
  web:
    build:
      context: $TMPDIR/$(get_repo_name ${REPO_LIST[0]})
    depends_on:
      - api
    restart: always
    ports:
      - "$PORT_WEB:8080"
    networks:
      - acrarm_default
  api:
    build:
      context: $TMPDIR/$(get_repo_name ${REPO_LIST[1]})
    depends_on:
      - mongo
    restart: always
    ports:
      - "$PORT_API:8080"
    networks:
      - acrarm_default
 # msp:
 #   build:
 #     context: $TMPDIR/$(get_repo_name ${REPO_LIST[2]})
 #   restart: unless-stopped
 #   ports:
 #      - "$PORT_MSP:8080"
 #   networks:
 #     - acrarm_default

networks:
  acrarm_default:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.16.0.0/16
EOF

docker-compose build --no-cache
docker-compose up -d
