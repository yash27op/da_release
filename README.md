# Ngrok Event logs

<img width="1397" alt="Screenshot 2025-06-25 at 11 16 51 PM" src="https://github.com/user-attachments/assets/307c9fe9-3da1-49fd-acf0-78244d9008b3" />

# Fast api End point

<img width="1477" alt="Screenshot 2025-06-25 at 11 17 38 PM" src="https://github.com/user-attachments/assets/cf2982f7-9e2a-420e-b2d2-3069415bdf76" />

# Readme.md gnerator

- "https://profile-readme-generator.com/"
- "https://rahuldkjain.github.io/gh-profile-readme-generator/"
- "https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent"
  
<img width="1167" height="615" alt="Screenshot 2025-07-14 at 12 37 36 AM" src="https://github.com/user-attachments/assets/10d56957-8733-4efd-83da-3dbdb7774c96" />

## 📌 Setup Instructions

![image](https://github.ibm.com/GoldenEyeIndianSquad/da-release-pipeline/assets/490540/d873ad58-e6ca-40e6-9d18-7798831d0820)

## ⚙️ Prerequisites To run Pipeline in Local

- Kubernetes Cluster (Minikube, Kind,GKE, EKS, etc.)
- `kubectl` installed and configured
  ```bash
  brew install kubectl
   ```
- Tekton Pipelines & Triggers installed
- Docker / Rancher / Container Registry access (DockerHub, GitHub Container Registry, etc.)

### 1. Install Tekton CRDs

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
brew install tektoncd-cli
```

## ℹ️ Output Expected respect to commands :-

```bash
kubectl get namespaces
```
![Namespaces](https://github.ibm.com/Yash-Naik/Tekton-Basics/blob/858c529e118aab0c61d29b5a8db83a8aca4416a4/images/namespace.png)

```bash
kubectl get pods -n tekton-pipelines
```
![Tekton pods running](https://github.ibm.com/Yash-Naik/Tekton-Basics/blob/f82697499587cb936e8c44020c31505533c47924/images/tekton%20-pods.png)


### 2. Command for different components of tekton

```bash

kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

```
## 🧾 ***Tekton Dashboard***
```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
kubectl --namespace tekton-pipelines port-forward svc/tekton-dashboard 9097:9097
```

![tekton-dashboard](https://github.ibm.com/Yash-Naik/Tekton-Basics/blob/99ee648694c7962e818b33dfc822750208d6e14f/images/tekton-dashboard.png)
