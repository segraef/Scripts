#!/bin/sh

# https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops

# Creates directory & download ADO agent install files

su - <<GENERIC_VALUE>> -c "
mkdir myagent && cd myagent
wget https://vstsagentpackage.azureedge.net/agent/2.186.1/vsts-agent-linux-x64-2.186.1.tar.gz
tar zxvf vsts-agent-linux-x64-2.186.1.tar.gz"

# Unattended install

su - <<GENERIC_VALUE>> -c "
./config.sh --unattended \
  --agent "$(hostname)" \
  --url "https://dev.azure.com/prefix" \
  --auth PAT \
  --token "PATPATPAT" \
  --pool "Default" \
  --replace \
  --acceptTeeEula & wait $!"

cd /home/<<GENERIC_VALUE>>/
#Configure as a service
sudo ./svc.sh install <<GENERIC_VALUE>>

#Start svc
sudo ./svc.sh start