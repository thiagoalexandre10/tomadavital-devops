
#!/bin/bash
# Tomada Vital - Infraestrutura Azure
set -eo pipefail

RM="RM567486"
GRUPO="rg-tomadavital-$RM"
LOCAL="spaincentral"
VM="vm-tomadavital"
LOG="deploy-azure.log"

echo "== 1/4 Criando o grupo de recursos"
az group create --name "$GRUPO" --location "$LOCAL" 2>&1 | tee -a "$LOG"

echo "== 2/4 Criando a VM Ubuntu (Standard_B2ls_v2, 4 GB)"
az vm create --resource-group "$GRUPO" --name "$VM" --location "$LOCAL" --image Ubuntu2204 --size Standard_B2ls_v2 --zone 2 --admin-username azureuser --generate-ssh-keys --public-ip-sku Standard 2>&1 | tee -a "$LOG"

echo "== 3/4 Abrindo a porta 8080 da API"
az vm open-port --resource-group "$GRUPO" --name "$VM" --port 8080 2>&1 | tee -a "$LOG"

echo "== 4/4 Instalando Docker e Docker Compose"
az vm run-command invoke --resource-group "$GRUPO" --name "$VM" --command-id RunShellScript --scripts "curl -fsSL https://get.docker.com | sh && usermod -aG docker azureuser" 2>&1 | tee -a "$LOG"

IP=$(az vm show -d --resource-group "$GRUPO" --name "$VM" --query publicIps -o tsv)

echo "Pronto. IP publico: $IP" | tee -a "$LOG"
echo "Entre na VM com: ssh azureuser@$IP" | tee -a "$LOG"
