# ☸️ Kubernetes Cluster — Hotel Management System

<div align="center">

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX_Ingress-009639?style=for-the-badge&logo=nginx&logoColor=white)
![KinD](https://img.shields.io/badge/KinD_Cluster-purple?style=for-the-badge)

**A production-grade Kubernetes cluster deploying a full-stack Hotel Management System**  
with a 3-node KinD cluster, NGINX Ingress, MySQL StatefulSet, and workload isolation via Node Taints & Affinity.

[Architecture](#-architecture) · [K8s Objects](#-kubernetes-objects) · [Database Schema](#-database-schema) · [Deployment](#-deployment-guide) · [Authors](#-authors)

</div>

---

## 📖 Overview

This project deploys a **full-stack Hotel Management System** on a local Kubernetes cluster using **KinD (Kubernetes in Docker)**. The system follows a 3-tier architecture (Frontend → Backend → MySQL) and demonstrates real-world Kubernetes concepts including:

- Node isolation with **Taints & Tolerations**
- Workload placement with **Node Affinity**
- Persistent storage with **PV / PVC**
- Secure configuration with **Secrets & ConfigMaps**
- External traffic routing via **NGINX Ingress Controller**
- Database initialization via **Init Containers**
- Resource governance with **LimitRange**

All workloads are deployed in a dedicated `hotel-app` namespace.

---

## 🏗️ Architecture

![Cluster Diagram](k8s%20objects/Cluster%20diagram%20(1).png)

### Cluster Layout

```
Kubernetes Cluster (KinD — 3 nodes)
│
├── Master Node (Control Plane)
│   ├── API Server
│   ├── Scheduler
│   ├── etcd
│   └── Controller Manager
│
├── Worker Node 1  ─── label: app=frontend-node
│   └── Frontend Deployment (2 replicas)
│       ├── frontend-container (port 80)
│       ├── ConfigMap (env vars)
│       ├── LimitRange
│       └── frontend-service (ClusterIP)
│
└── Worker Node 2  ─── label: app=backend-node  |  taint: type=db-backend:NoSchedule
    ├── Backend Deployment (2 replicas)
    │   ├── backend-container (port 8080)
    │   ├── initContainer: wait-for-mysql
    │   ├── ConfigMap + Secret (DB credentials)
    │   ├── LimitRange
    │   └── backend-service (ClusterIP)
    │
    └── MySQL StatefulSet (1 replica)
        ├── mysql-container (port 3306)
        ├── Init SQL script via ConfigMap
        ├── Secret (root & user password)
        ├── PVC → PV → AWS EBS (10Gi)
        └── mysql-service (ClusterIP)
```

### Traffic Flow

```
User → AWS Load Balancer → NGINX Ingress Controller
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
              route "/"                   route "/api"
                    │                           │
            frontend-service           backend-service
                    │                           │
            Frontend Pods (×2)         Backend Pods (×2)
                                               │
                                         mysql-service
                                               │
                                        MySQL StatefulSet
```

---

## 📦 Kubernetes Objects

| File | Kind | Purpose |
|------|------|---------|
| `NameSpace.yml` | Namespace | Isolates all resources under `hotel-app` |
| `Secret.yml` | Secret | Stores base64-encoded DB password securely |
| `BackendConfigMap.yml` | ConfigMap | Provides `DB_HOST`, `DB_USER`, `DB_NAME` to backend |
| `FrontendConfigMap.yml` | ConfigMap | Provides `BACKEND_URL`, `API_BASE_URL`, `APP_NAME` to frontend |
| `init-database.yml` | ConfigMap | SQL init script — creates tables & seeds data on first run |
| `LimitRange.yml` | LimitRange | Enforces CPU/memory defaults and limits per container |
| `PV.yml` | PersistentVolume | 10Gi host-path volume for MySQL data |
| `PVC.yml` | PersistentVolumeClaim | Binds to PV and mounts into MySQL pod |
| `MySQLStatefulSet.yml` | StatefulSet | Runs MySQL 8 with stable identity and persistent storage |
| `MySQLService.yml` | Service (ClusterIP) | Exposes MySQL internally at port 3306 |
| `BackendDeployment.yml` | Deployment | 2-replica backend with init container & node affinity |
| `BackendService.yml` | Service (ClusterIP) | Exposes backend API internally at port 8080 |
| `FrontendDeployment.yml` | Deployment | 2-replica frontend with soft node affinity |
| `FrontendService.yml` | Service (ClusterIP) | Exposes frontend internally at port 80 |
| `IngressController.yml` | Ingress | NGINX routes `/` → frontend, `/api` → backend |

---

## 🔒 Workload Isolation Strategy

### Node Taint & Toleration
Worker Node 2 is tainted to prevent general workloads from being scheduled there:
```bash
kubectl taint nodes desktop-control-plane type=db-backend:NoSchedule
kubectl label nodes desktop-control-plane node-type=backend-db
```
Only the **Backend** and **MySQL** pods carry the matching `toleration`, ensuring the database node is isolated from frontend traffic.

### Node Affinity
- **Backend & MySQL** → `requiredDuringScheduling` — must run on `node-type=backend-db`
- **Frontend** → `preferredDuringScheduling` — prefers nodes that are NOT `backend-db`

This guarantees complete workload separation between frontend and backend/database tiers.

---

## 🛡️ Security & Configuration

### Secret Management
Database credentials are stored as a Kubernetes `Secret` (Opaque type) using base64 encoding:
```yaml
data:
  DB_PASSWORD: aG90ZWwxMjM=   # base64(hotel123)
```
The backend and MySQL pods consume this secret via `secretKeyRef` — credentials are never hardcoded in deployment specs.

### ConfigMaps
Non-sensitive configuration is injected via ConfigMaps as environment variables:

**Backend ConfigMap:**
```
DB_HOST=mysql-service
DB_USER=hotel
DB_NAME=hotel_db
```

**Frontend ConfigMap:**
```
BACKEND_URL=http://backend-service:8080
API_BASE_URL=http://backend-service:8080/api
APP_NAME=Hotel Management System
ENVIRONMENT=production
```

---

## 💾 Persistent Storage

MySQL data is persisted using a PV/PVC pair:

| Property | Value |
|----------|-------|
| Storage Class | `standard` |
| Access Mode | `ReadWriteOnce` |
| Capacity | `10Gi` |
| Host Path | `/host_mnt/d/data/mysql` |

The PVC is mounted into the MySQL StatefulSet at `/var/lib/mysql`, ensuring data survives pod restarts.

---

## 🗄️ Database Schema

The database is automatically initialized via a SQL ConfigMap mounted at `/docker-entrypoint-initdb.d`.

### Tables

**`users`** — Hotel guests / registered accounts
```sql
id, username, email, password, first_name, last_name, phone, created_at, updated_at
```

**`rooms`** — Available hotel rooms
```sql
id, room_number, room_type, capacity, price_per_night, description, is_available, created_at, updated_at
```

**`bookings`** — Guest room reservations
```sql
id, user_id (FK), room_id (FK), check_in_date, check_out_date, total_price, status, created_at, updated_at
```

**`reviews`** — Guest reviews per room
```sql
id, user_id (FK), room_id (FK), rating (1–5), comment, created_at, updated_at
```

### Performance Indexes
```sql
idx_user_email         ON users(email)
idx_booking_user       ON bookings(user_id)
idx_booking_room       ON bookings(room_id)
idx_booking_dates      ON bookings(check_in_date, check_out_date)
idx_review_room        ON reviews(room_id)
```

### Seed Data
5 rooms are pre-seeded on first startup (Single, Double, Suite types at varying prices).

---

## ⚙️ Resource Management

A `LimitRange` is applied at the namespace level to enforce resource boundaries:

| | CPU | Memory |
|-|-----|--------|
| **Default Request** | 200m | 256Mi |
| **Default Limit** | 500m | 512Mi |

Individual deployments override these defaults as needed:
- **Frontend pods**: request 100m CPU / 128Mi RAM, limit 300m / 256Mi
- **Backend pods**: request 200m CPU / 256Mi RAM, limit 500m / 512Mi

---

## 🚀 Deployment Guide

### Prerequisites
- Docker installed and running
- `kubectl` installed
- `kind` v0.22.0+

### Step 1 — Create the KinD Cluster

```bash
# Install KinD
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# Create cluster config
cat > cluster.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

kind create cluster --name mycluster --config cluster.yaml
kubectl get nodes
```

### Step 2 — Taint & Label the Backend Node

```bash
kubectl taint nodes desktop-control-plane type=db-backend:NoSchedule
kubectl label nodes desktop-control-plane node-type=backend-db
```

### Step 3 — Deploy All Objects (in order)

```bash
# Namespace
kubectl apply -f code/NameSpace.yml

# Secrets & Config
kubectl apply -f code/Secret.yml
kubectl apply -f code/BackendConfigMap.yml
kubectl apply -f code/FrontendConfigMap.yml
kubectl apply -f code/init-database.yml

# Resource Limits
kubectl apply -f code/LimitRange.yml

# Storage
kubectl apply -f code/PV.yml
kubectl apply -f code/PVC.yml

# MySQL
kubectl apply -f code/MySQLStatefulSet.yml
kubectl apply -f code/MySQLService.yml

# Backend
kubectl apply -f code/BackendDeployment.yml
kubectl apply -f code/BackendService.yml

# Frontend
kubectl apply -f code/FrontendDeployment.yml
kubectl apply -f code/FrontendService.yml

# Ingress
kubectl apply -f code/IngressController.yml
```

### Step 4 — Verify the Deployment

```bash
kubectl get pods -n hotel-app -o wide
kubectl get svc -n hotel-app
kubectl get ingress -n hotel-app
kubectl get pvc -n hotel-app
kubectl get nodes --show-labels
kubectl describe node desktop-control-plane | grep Taints
```

### Step 5 — Access the Application

Add to `/etc/hosts`:
```
127.0.0.1   hotel.local
```

Then open in your browser:
- **Frontend:** `http://hotel.local/`
- **Backend API:** `http://hotel.local/api`

---

## 📋 Deployment Order Summary

| Step | Object | Purpose |
|------|--------|---------|
| 1 | Namespace | Scope all resources |
| 2 | Taint & Label | Isolate the DB/backend node |
| 3 | Secret + ConfigMaps | Inject credentials & config |
| 4 | LimitRange | Enforce resource governance |
| 5 | PV + PVC | Provision persistent storage |
| 6 | MySQL StatefulSet + Service | Start the database |
| 7 | Backend Deployment + Service | Start the API server |
| 8 | Frontend Deployment + Service | Start the web app |
| 9 | Ingress | Enable external routing |
| 10 | Verify | Check all pods are running |

---

## 👥 Authors

| Name | Role |
|------|------|
| **Zeyad Bilal** | Co-Developer |
| **Abdelaziz Hassan** | Co-Developer |

> Created: December 2025

---

## 📄 License

This project is licensed under the **MIT License**.

---

<div align="center">
Built with ☸️ Kubernetes · 🐳 Docker · 🐬 MySQL · 🔀 NGINX Ingress
</div>

