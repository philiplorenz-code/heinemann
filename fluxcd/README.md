# Installation und Setup minikube - Unter MacOS:
```bash
brew install minikube
minikube start --driver=docker
kubectl config use-context minikube
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
```

# minikube Tunnel starten:
```bash
minikube tunnel
```

# GitHub Token
```bash
export GITHUB_USER="<IhrGitHubUser>"
export GITHUB_TOKEN="<IhrPAT_mit_repo_Rechten>"
```

# Setup Flux
```bash
flux bootstrap github \
  --owner="$GITHUB_USER" \
  --repository=heinemann \
  --branch=main \
  --path=./fluxcd/clusters/clusterA \
  --personal
```