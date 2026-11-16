#!/bin/bash
# Apaga TUDO o que foi criado (grupo de recursos inteiro). Espera terminar para mostrar no video.
set -e
RM="RM000000"
GRUPO="rg-tomadavital-$RM"
az group delete --name $GRUPO --yes
echo "Grupo existe ainda? $(az group exists --name $GRUPO)"
