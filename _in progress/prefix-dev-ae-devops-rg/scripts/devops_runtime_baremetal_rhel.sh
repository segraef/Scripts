#!/bin/sh

url=${1}
pat_token=${2}
agent_pool=${3}
agent_prefix=${4}
num_agent=${5}
admin_user=${6}
rover_version="${7}"

error() {
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    if [[ -n "$message" ]] ; then
        >&2 echo -e "\e[41mError on or near line ${parent_lineno}: ${message}; exiting with status ${code}\e[0m"
    else
        >&2 echo -e "\e[41mError on or near line ${parent_lineno}; exiting with status ${code}\e[0m"
    fi
    echo ""
    exit "${code}"
}

function cleanup {
  echo "calling cleanup"

  echo "stopping the service"
  sudo ./svc.sh stop || true
  echo "uninstall the service"
  sudo ./svc.sh uninstall || true
  echo "un-register from AZDO"
  sudo -u ${admin_user} ./config.sh remove --unattended --auth pat --token ${pat_token} || true
}

set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

#strict mode, fail on error
# set -euo pipefail

echo "start"

echo "install Ubuntu packages"


yum update -y
# install docker
yum module remove container-tools
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
sed -i s/7/8/g /etc/yum.repos.d/docker-ce.repo
yum install docker-ce -y

echo "Allowing agent to run docker"

usermod -aG docker ${admin_user}
systemctl daemon-reload
systemctl enable docker
service docker start
docker --version

# Pull rover base image

# echo "Rover docker image ${rover_version}"
# docker pull "${rover_version}" 2>/dev/null

echo "Installing Azure CLI"

# install azure cli
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
sudo yum install azure-cli -y

echo "install VSTS Agent"

cd /usr
mkdir -p agent
cd agent

echo "Installing required packages for agents"

### Install wget ###
yum install wget -y

### Install Terraform ###
yum install zip unzip -y

sudo wget -P /usr/src https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip
unzip /usr/src/terraform_0.13.5_linux_amd64.zip -d /usr/src/terraform
sudo rm -rf /usr/src/terraform_0.13.5_linux_amd64.zip
sudo ln -s /usr/src/terraform/terraform /usr/bin/terraform


# install packer
curl -SL https://releases.hashicorp.com/packer/1.6.2/packer_1.6.2_linux_amd64.zip -o packer_1.6.2_linux_amd64.zip
unzip packer_1.6.2_linux_amd64.zip
sudo mv packer /usr/bin/packer


# Install powershell
curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
sudo yum install -y powershell

# install python3 & pip3
yum install -y python3

# install ansible
pip3 install ansible --user

# install python netaddr
pip3 install netaddr
pip3 install dnspython
cp /root/.local/bin/* /usr/local/bin

# install jq
JQ=/usr/bin/jq
curl https://stedolan.github.io/jq/download/linux64/jq > $JQ && chmod +x $JQ
ls -la $JQ

# install git
sudo yum install git -y

AGENTRELEASE="$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")')"
AGENTURL="https://vstsagentpackage.azureedge.net/agent/${AGENTRELEASE}/vsts-agent-linux-x64-${AGENTRELEASE}.tar.gz"
echo "Release "${AGENTRELEASE}" appears to be latest"
echo "Downloading..."
curl -s ${AGENTURL} -o agent_package.tar.gz

for agent_num in $(seq 1 ${num_agent}); do
  agent_dir="agent-$agent_num"
  mkdir -p "$agent_dir"
  cd "$agent_dir"
    echo "moving to $agent_dir"

    cleanup

    name="${agent_prefix}-${agent_num}"
    echo "installing agent $name"
    tar zxvf ../agent_package.tar.gz
    chmod -R 777 .
    echo "extracted"
    ./bin/installdependencies.sh || true
    echo "dependencies installed"
    sudo -u ${admin_user} ./config.sh --unattended --url "${url}" --auth pat --token "${pat_token}" --pool "${agent_pool}" --agent "${name}" --acceptTeeEula   --replace --work ./_work --runAsService
    echo "configuration done"
    ./svc.sh install
    echo "service installed"
    ./svc.sh start
    echo "service started"
    echo "config done"
  cd ..
done
