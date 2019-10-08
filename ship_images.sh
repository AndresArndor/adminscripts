#!/bin/bash

IMAGE_LIST=( "acrarm_api" "acrarm_web" "acrarm_keycloak_image" "certbot/certbot" "swaggerapi/swagger-ui" "nginx" "node" "jboss/keycloak" "fauria/vsftpd" "hello-world" )

TAR_DIR=tared_images_acrarm

function rename_image {
  case ${image_name} in
    certbot/certbot)
      tar_name="certbot"
      ;;
    swaggerapi/swagger-ui)
      tar_name="swagger"
      ;;
    jboss/keycloak)
      tar_name="jbosskeycloak"
      ;;
    fauria/vsftpd)
      tar_name="vsftpd"
      ;;
  esac
}

function tar_image {
  docker save --output ${tar_name}.tar ${image_name}
}

function untar_image {
  docker load --input ${tared_image}
}

if [ -d $TAR_DIR ]; then
  cd $TAR_DIR
else
  mkdir $TAR_DIR
  cd $TAR_DIR
fi

case ${1} in
  tar)
    for i in ${IMAGE_LIST[@]}; do
      tar_name=${i}
      image_name=${i}
      echo $image_name
      rename_image
      tar_image
    done
    ;;
  untar)
    TAR_LIST=`ls`
    for i in ${TAR_LIST[@]}; do
      echo ${i}
      tared_image=${i}
      untar_image
    done
    ;;
esac
