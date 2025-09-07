brew install minikube
minikube start --driver=docker
kubectl config use-context minikube
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
