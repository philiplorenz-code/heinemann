helm repo add netbox-community https://charts.netbox.oss.netboxlabs.com/
helm repo update
helm install netbox netbox-community/netbox --namespace netbox --create-namespace