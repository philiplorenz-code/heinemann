az group create --name my-aca-rg --location westeurope

az containerapp up \
  --name my-aca-app \
  --resource-group my-aca-rg \
  --environment my-aca-env \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --target-port 80 \
  --ingress external
