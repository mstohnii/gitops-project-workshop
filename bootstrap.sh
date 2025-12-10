#!/usr/bin/env bash  
set -euo pipefail  
  
# ------------------------------  
# Налаштування  
# ------------------------------  
REPO_URL="https://github.com/mstohnii/gitops-project-workshop.git"  
MINIKUBE_PROFILE="gitops-workshop"  
K8S_VERSION="v1.30.0"  
ARGO_NS="argocd"  
  
# ------------------------------  
# Перевірка залежностей  
# ------------------------------  
need_cmd() {  
  if ! command -v "$1" >/dev/null 2>&1; then  
    echo "ERROR: потрібна команда '$1' (установіть і запустіть скрипт ще раз)" >&2  
    exit 1  
  fi  
}  
  
need_cmd kubectl  
need_cmd helm  
need_cmd minikube  
  
# ------------------------------  
# Старт Minikube  
# ------------------------------  
echo "[*] Стартуємо Minikube..."  
minikube start \  
  --profile="${MINIKUBE_PROFILE}" \  
  --kubernetes-version="${K8S_VERSION}" \  
  --cpus=4 \  
  --memory=4096 \  
  --driver=docker  
  
kubectl config use-context "${MINIKUBE_PROFILE}"  
  
# (опційно) metrics-server  
minikube addons enable metrics-server --profile "${MINIKUBE_PROFILE}"  
  
# ------------------------------  
# Встановлення Argo CD через Helm  
# ------------------------------  
echo "[*] Встановлюємо Argo CD..."  
kubectl get ns "${ARGO_NS}" >/dev/null 2>&1 || kubectl create ns "${ARGO_NS}"  
  
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null  
helm repo update >/dev/null  
  
helm upgrade --install argocd argo/argo-cd \  
  --namespace "${ARGO_NS}" \  
  --values gitops/argocd/values.yaml  
  
echo "[*] Чекаємо готовність Argo CD..."  
kubectl -n "${ARGO_NS}" rollout status deploy/argocd-server --timeout=300s  
  
# ------------------------------  
# Root Application (GitOps App-of-Apps)  
# ------------------------------  
echo "[*] Створюємо root ArgoCD Application..."  
kubectl apply -f gitops/root-app.yaml  
  
cat <<EOF  
  
========================================  
Готово.  
  
Argo CD:  
  kubectl port-forward svc/argocd-server -n argocd 8080:80  
  Логін за замовчуванням:  
    user: admin  
    pass: $(kubectl -n argocd get secret argocd-initial-admin-secret \  
                 -o jsonpath="{.data.password}" | base64 -d)  
  
Grafana:  
  після деплою monitoring:  
  kubectl port-forward svc/vm-k8s-stack-grafana -n monitoring 3000:80  
  user: admin  
  pass: admin (див. values Helm-чарту)  
  
Перевірка GitOps:  
  - змініть репліки або параметри в charts/spam2000/values.yaml  
  - git commit && git push  
  - Argo CD автоматично оновить Deployment у кластері  
========================================  
EOF  
