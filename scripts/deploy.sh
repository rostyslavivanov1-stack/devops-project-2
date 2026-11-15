#!/usr/bin/env bash
set -euo pipefail

if ! minikube status 2>/dev/null | grep -q "host: Running"; then
  echo "Кластер не активний. Запуск minikube..."
  minikube start --driver=docker
else
  echo "Кластер Minikube вже запущено."
fi

echo -e "\n=== 1. Активація необхідних аддонів (Ingress, Metrics Server) ==="
minikube addons enable ingress
minikube addons enable metrics-server

echo -e "\n=== 2. Збірка та імпорт Docker-образів у Minikube ==="
docker build -t fastapi-app:v1 ./app
minikube image load fastapi-app:v1
docker pull coleifer/sqlite-web:latest
minikube image load coleifer/sqlite-web:latest

echo -e "\n=== 3. Застосування маніфестів високого рівня ==="
kubectl apply -f k8s/high-level/

echo -e "\n=== 4. Очікування готовності деплойментів ==="
kubectl rollout status deployment/fastapi-deployment --timeout=120s
kubectl rollout status deployment/sqlite-web-deployment --timeout=120s

echo -e "\n=== 5. Підсумковий стан об'єктів у кластері ==="
kubectl get pods,deployments,replicasets,services,ingress,pv,pvc

echo -e "\nРозгортання успішно завершено!"