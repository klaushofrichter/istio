#!/bin/bash
# setting up linux environment
set -e

#K3DVERSION="5.2.2"
K3DVERSION="5.3.0"
NVMVERSION="0.39.0"
NODEVERSION="14.18"
HELMVERSION="3.7.2"

echo "sudo root access needed for some operations"
sudo apt-get update

# NO NEED TO INSTALL DOCKER ON LINUX IF YOU INSTALLED Docker Desktop ON THE WINDOWS SIDE.
#echo
#echo "Installing Docker"
## Docker: https://docs.docker.com/engine/install/ubuntu/
#sudo apt-get install ca-certificates curl gnupg lsb-release -y
##rm -f /usr/share/keyrings/docker-archive-keyring.gpg
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
#echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#sudo apt-get update
#sudo apt-get install docker-ce docker-ce-cli containerd.io -y

echo
echo "Installing K3D"
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v${K3DVERSION} bash

echo
echo "Installing helm"
# https://helm.sh/docs/intro/install/
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION="v${HELMVERSION}" bash

echo
echo "Installing jq"
# https://stedolan.github.io/jq/
sudo apt install jq -y

echo
echo "Installing nodejs"
#NODE JS:  https://docs.microsoft.com/en-us/windows/dev-environment/javascript/nodejs-on-wsl
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVMVERSION}/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install ${NODEVERSION}
echo
echo "# run the following commands in the terminal to enable Node Version Manager".
echo "export NVM_DIR=\"\\$HOME/.nvm\""
echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" 
echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\""

# Enable docker commands for $USER
sudo usermod -aG docker $USER
newgrp docker
