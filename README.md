# Kubernetes Praxistransferprojekt – Community Pulse

**Autor:** Konstantin Isidor Muschallik (Matrikelnr. 653242001)  
**Hochschule:** Rheinische Hochschule Köln • Fachbereich Ingenieurwesen (B.Sc. Informatik)  
**Erstprüfer:** Prof. Dr. Friedel Mager • Wintersemester 2026  

---

## 📌 Übersicht & Architektur

Dieses Repository enthält den vollständigen Quellcode und die deklarativen Kubernetes-Manifeste für das Praxistransferprojekt.

### 3-Tier-Architektur
1. **Frontend (Tier 1):** Responsive Single-Page Application (HTML5, Tailwind CSS, Vanilla JS) serviert via Nginx Alpine. Zeigt Cluster-Informationen (Pod-Name, Node-Name), DB-Verbindungsstatus, Latenz und Live-Feed.
2. **Backend (Tier 2):** Asynchrone REST-API in Python (FastAPI). Stellt Endpoints für Datenbereitstellung, Health-Checks (`/healthz`, `/ready`), Prometheus-Metriken (`/metrics`) sowie einen Lastgenerator (`/api/v1/work`) für HPA-Tests bereit.
3. **Persistenz (Tier 3):** PostgreSQL-Datenbank mit persistentem Volume (`PersistentVolumeClaim`) für zuverlässige Datenspeicherung.

---

## 🛠 Verzeichnisstruktur

```text
k8s-praxisprojekt/
├── app/
│   ├── backend/                 # FastAPI REST API & Dockerfile
│   └── frontend/                # Web Dashboard, Nginx Config & Dockerfile
│
├── k8s/                         # Deklarative Konfiguration mit Kustomize
│   ├── base/                    # Basis-Ressourcen (Deployments, Services, Ingress, PVC)
│   └── overlays/
│       ├── dev/                 # Entwicklungsumgebung (Single-Replica)
│       └── prod/                # Produktivumgebung (Multi-Replica, HPA Autoscaling)
│
├── monitoring/                  # Observability
│   ├── prometheus.yaml          # Prometheus Deployment & Scrape-Config
│   └── grafana.yaml             # Grafana & Prometheus Datasource
│
├── .github/workflows/
│   └── ci-cd.yaml               # GitHub Actions: Lint, Build, Push nach GHCR
│
└── scripts/                     # Automatisierungsskripte
    ├── 01-setup-master.sh       # K3s Master auf AWS EC2 Node 1 installieren
    ├── 02-join-worker.sh        # AWS EC2 Node 2 als Worker joinen
    ├── 03-deploy.sh             # Applikation & Monitoring ausrollen
    └── 04-load-test.sh          # Lasttest ausführen (HPA-Demonstration)
```

---

## 🚀 Schritt-für-Schritt-Anleitung (AWS Free Tier)

### 1. Vorbereitung auf AWS
* 2x EC2-Instanzen starten (`t3.micro` oder `t2.micro` mit Ubuntu 22.04 / 24.04).
* Security Group Ports öffnen:
  * `22` (SSH)
  * `80`, `443` (HTTP/HTTPS für Traefik Ingress)
  * `6443` (K3s Kubernetes API Server – intern für Worker)
  * `3000` (Grafana Web UI)

### 2. Master-Node einrichten (Node 1)
Auf Node 1 per SSH einloggen und ausführen:
```bash
git clone <DEIN_REPO_URL>
cd k8s-praxisprojekt
./scripts/01-setup-master.sh
```
*Merke dir die ausgegebene Private IP und das Node-Token!*

### 3. Worker-Node verbinden (Node 2)
Auf Node 2 per SSH einloggen und ausführen:
```bash
git clone <DEIN_REPO_URL>
cd k8s-praxisprojekt
./scripts/02-join-worker.sh <MASTER_PRIVATE_IP> <NODE_TOKEN>
```

### 4. Anwendung & Monitoring deployen
Zurück auf Node 1:
```bash
./scripts/03-deploy.sh
```

### 5. Validierung & Live-Demo
* **Web-App im Browser öffnen:** `http://<PUBLIC_IP_NODE_1>/`
* **Grafana aufrufen:** `http://<PUBLIC_IP_NODE_1>:3000` (Login: `admin` / `admin`)
* **HPA-Lasttest ausführen:**
  ```bash
  ./scripts/04-load-test.sh http://<PUBLIC_IP_NODE_1>/api/v1/work?iterations=600000
  ```
  Beobachte, wie Kubernetes die Backend-Pods automatisch von 2 auf bis zu 5 Instanzen hochskaliert!
