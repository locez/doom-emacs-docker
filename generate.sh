#!/bin/bash
set -e

fetch_profile () {
  grep "^\([^:]*:\)\{2\}$1" "$2"
}

parse_profile () {
  echo "$1" | awk -F':' "{ print \$$2; }"
}

BASE_IMAGE="$1"
USER_PROFILE="$(fetch_profile "${UID}" /etc/passwd)"
USER="$(parse_profile "${USER_PROFILE}" 1)"
GID="$(parse_profile "${USER_PROFILE}" 4)"
HOME="$(parse_profile "${USER_PROFILE}" 6)"
GROUP_PROFILE="$(fetch_profile "${GID}" /etc/group)"
GROUP="$(parse_profile "${USER_PROFILE}" 1)"

IMAGE_NAME="doom-emacs"
read -p "Enter the image name(default: ${IMAGE_NAME}): " IMAGE_NAME
if [ -z "$IMAGE_NAME" ];then
    IMAGE_NAME="doom-emacs"
fi

DOCKERFILE=Dockerfile
cat <<EOF > ${DOCKERFILE}
FROM archlinux:latest
SHELL ["/bin/bash", "-c"]
RUN pacman -Syu --noconfirm && \
    pacman -S emacs git ripgrep base-devel librime librime-data fd --noconfirm

ENV DISPLAY=${DISPLAY}
RUN mkdir -p ${HOME} && \\
    echo "${USER}:x:${UID}:${GID}::${HOME}:/bin/bash" >> /etc/passwd && \\
    echo "${GROUP}:x:${GID}:" >> /etc/group && \\
    mkdir -p /etc/sudoers.d && \\
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} && \\
    chmod 0440 /etc/sudoers.d/${USER} && \\
    chown ${UID}:${GID} -R ${HOME} && \\
    echo "export DISPLAY=${DISPLAY}" >> /etc/profile
    
RUN echo "root:root" | chpasswd   
# setup entrypoint
COPY ./entrypoint.sh /

USER ${USER}
ENV HOME ${HOME}
RUN git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d && \
    ~/.emacs.d/bin/doom -y install


ENTRYPOINT ["/entrypoint.sh"]
EOF

echo ""
echo "Generated Dockerfile:"
echo "======================"
cat ${DOCKERFILE}
echo "======================"

COMPOSEFILE=docker-compose.yml


CONFIG=${HOME}/.doom.d/
read -p "Enter your config path(default ${CONFIG}):" CONFIG
if [ -z "$CONFIG" ];then
    CONFIG="${HOME}/.doom.d/"
fi

WORKSPACE=${HOME}/workspace
read -p "Enter your workspace path(default ${WORKSPACE}):" WORKSPACE
if [ -z "$WORKSPACE" ];then
    WORKSPACE="${HOME}/workspace"
fi



cat << EOF > ${COMPOSEFILE}
version: "3"
services:
  doom:
    build:
      context: .
      dockerfile: Dockerfile
    image: ${IMAGE_NAME}:latest
    volumes:
      - "/home/${USER}/.Xauthority:/home/${USER}/.Xauthority"
      - "/tmp/.X11-unix/:/tmp/.X11-unix/"
      - "/dev/snd:/dev/snd"
      - "/dev/shm:/dev/shm"
      - "/etc/machine-id:/etc/machine-id"
      - "/var/lib/dbus:/var/lib/dbus"
      - "${CONFIG}:${CONFIG}"
      - "${WORKSPACE}:${WORKSPACE}"
    extra_hosts:
      - "${HOSTNAME}:127.0.0.1"
    network_mode: "host"
    privileged: true
EOF

echo ""
echo "Generated docker-compose.yml:"
echo "======================"
cat ${COMPOSEFILE}
echo "======================"


read -p "Build image now? (y/N) " answer
while true; do
  case "$answer" in
    [yY])
      echo "Now building the image..."
      sudo docker-compose -f "$COMPOSEFILE" build 
      break;;
    [nN])
      break;;
    *)
      read -p "$answer is an invalid input, put either 'y' or 'n': " answer
  esac
done

SCRIPT_NAME=doom-emacs
SCRIPT_NAME=$(echo ${SCRIPT_NAME} |tr '_' '\-')

read -p "Generate ${SCRIPT_NAME} script? (y/N) " answer
while true; do
  case "$answer" in
    [yY])
      echo "install to ${HOME}/.local/bin/..."
      INSTALL_PATH=${HOME}/.local/bin/
      mkdir -p ${INSTALL_PATH}
      cat << EOF > ${INSTALL_PATH}/${SCRIPT_NAME}
#!/usr/bin/env bash
CID=\$(docker ps | grep ${IMAGE_NAME} |cut -d ' ' -f1)
option=""
if [ -z "\$*" ]; then
	option="run"
        docker exec --user \$USER \$CID bash -c "export QT_X11_NO_MITSHM=1; ~/.emacs.d/bin/doom \$option " &
	disown
	exit 0

elif [ "\$1" == "shell" ]; then
         docker exec -it --user \$USER \$CID bash -c "export QT_X11_NO_MITSHM=1; bash"
else
	option="\$*"
fi
docker exec -it --user \$USER \$CID bash -c "export QT_X11_NO_MITSHM=1; ~/.emacs.d/bin/doom \$option"
EOF
      chmod +x ${INSTALL_PATH}/${SCRIPT_NAME}      
      break;;
    [nN])
      break;;
    *)
      read -p "$answer is an invalid input, put either 'y' or 'n': " answer
  esac
done

