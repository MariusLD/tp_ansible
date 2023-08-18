set -eo pipefail

CONTAINER_USER=$USER
ANSIBLE_DIR="ansible_dir"

help(){
  echo "
=== 🐳  Bienvenue sur ce script de gestion de machines virtuelles ! 🐳 ===
-c <nombre> : Création de <nombre> conteneurs 🛠
-i : Informations sur les conteneurs 📚
-s : Lancement des conteneurs ✅
-t : Stopper les conteneurs ⛔️
-d : Suppression des conteneurs 🗑️
-a : Création de l'inventaire Ansible 📦
  "
}

createContainers(){
  CONTAINER_NUMBER=$1
  CONTAINER_HOME=/home/${CONTAINER_USER}
  CONTAINER_CMD="sudo podman exec "

  id_already=`sudo podman ps -a --format '{{ .Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {count++} END {print count}'`
  id_min=$((id_already + 1))
  id_max=$((id_already + ${CONTAINER_NUMBER}))
  
	for i in $(seq $id_min $id_max);do
		sudo podman run -d --systemd=true --publish-all=true --name ${CONTAINER_USER}-debian-$i -h ${CONTAINER_USER}-debian-$i docker.io/priximmo/buster-systemd-ssh
		${CONTAINER_CMD} ${CONTAINER_USER}-debian-$i /bin/sh -c "useradd -m -p sa3tHJ3/KuYvI ${CONTAINER_USER}"
		${CONTAINER_CMD} ${CONTAINER_USER}-debian-$i /bin/sh -c "mkdir -m 0700 ${CONTAINER_HOME}/.ssh && chown ${CONTAINER_USER}:${CONTAINER_USER} ${CONTAINER_HOME}/.ssh"
		sudo podman cp ${HOME}/.ssh/id_rsa.pub ${CONTAINER_USER}-debian-$i:${CONTAINER_HOME}/.ssh/authorized_keys
		${CONTAINER_CMD} ${CONTAINER_USER}-debian-$i /bin/sh -c "chmod 600 ${CONTAINER_HOME}/.ssh/authorized_keys && chown ${CONTAINER_USER}:${CONTAINER_USER} ${CONTAINER_HOME}/.ssh/authorized_keys"
		${CONTAINER_CMD} ${CONTAINER_USER}-debian-$i /bin/sh -c "echo '${CONTAINER_USER}   ALL=(ALL) NOPASSWD: ALL'>>/etc/sudoers"
		${CONTAINER_CMD} ${CONTAINER_USER}-debian-$i /bin/sh -c "service ssh start"
	done

	infosContainers

  exit 0
}

infosContainers(){
	echo ""
	echo "Conteneur(s) actif(s) : "
	echo ""
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"{{.Name}} -- IP: {{.NetworkSettings.IPAddress}}\" "$1)}'
	echo ""
  exit 0
}

dropContainers(){
  sudo podman ps -a --format {{.Names}} | awk -v user=${CONTAINER_USER} '$1 ~ "^"user {print $1" - Suppression";system("sudo podman rm -f "$1)}'
  infosContainers
}

startContainers(){
  sudo podman ps -a --format {{.Names}} | awk -v user=${CONTAINER_USER} '$1 ~ "^"user {print $1" - Démarrage";system("sudo podman start "$1)}'
  infosContainers
}

stopContainers(){
  sudo podman ps -a --format {{.Names}} | awk -v user=${CONTAINER_USER} '$1 ~ "^"user {print $1" - Stop";system("sudo podman stop "$1)}'
  infosContainers
}

createAnsible(){
	echo ""
  mkdir -p ${ANSIBLE_DIR}
  echo "all:" > ${ANSIBLE_DIR}/00_inventory.yml
  echo "  vars:" >> ${ANSIBLE_DIR}/00_inventory.yml
  echo "    ansible_python_interpreter: /usr/bin/python3" >> ${ANSIBLE_DIR}/00_inventory.yml
  echo "  hosts:" >> ${ANSIBLE_DIR}/00_inventory.yml
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"    {{.NetworkSettings.IPAddress}}:\" "$1)}' >> ${ANSIBLE_DIR}/00_inventory.yml
  mkdir -p ${ANSIBLE_DIR}/host_vars
  mkdir -p ${ANSIBLE_DIR}/group_vars
	echo ""
}

if [ "$#" -eq  0 ];then
help
fi

while getopts ":c:ahitsd" options; do
  case "${options}" in 
		a)
			createAnsible
			;;
    c)
			createContainers ${OPTARG}
      ;;
		i)
			infosContainers
			;;
		s)
			startContainers
			;;
		t)
			stopContainers
			;;
		d)
			dropContainers
			;;
    h)
      help
      exit 1
      ;;
    *)
      help
      exit 1
      ;;
  esac
done
