# Multi-Container Application Deployment in Kubernetes (FastAPI + SQLite-web)

Практичний проєкт із розгортання клієнт-серверної системи моніторингу ресурсів ПК на базі **FastAPI**, **SQLite-web** та Python-агента у локальному кластері **Kubernetes (Minikube)** з автоматизацією розгортання та CI/CD-пайплайном **GitHub Actions**[cite: 5, 10].

## Архітектура системи

* **Host Monitoring Agent (`host_monitoring_agent.py`):** клієнтський скрипт на хост-машині, який періодично зчитує завантаження CPU та надсилає метрики через HTTP `POST /metrics`[cite: 10].
* **Backend (`FastAPI`):** REST API сервіс (`app/main.py`), запакований у Docker-образ `fastapi-app:v1`, який приймає, зберігає, повертає та видаляє записи метрик[cite: 10, 12].
* **Database UI (`SQLite-web`):** вебінтерфейс (`coleifer/sqlite-web:latest`) для перегляду та редагування бази даних `app.db` у браузері[cite: 10, 12, 15].
* **Рівні оркестрації (`k8s/`):**
  * **`k8s/middle-level/` (Середній рівень):** розгортання обох контейнерів у межах **одного пода** (`monitoring-deployment`), обмін файлом БД через том `emptyDir` та публікація через сервіс типу `NodePort`[cite: 9, 12].
  * **`k8s/high-level/` (Високий рівень):** мікросервісна архітектура з поділом на **окремі поди** (`fastapi-deployment` та `sqlite-web-deployment`), збереженням даних у `PersistentVolume` (`hostPath`) через `PersistentVolumeClaim`, централізованою конфігурацією в `ConfigMap` та маршрутизацією трафіку через `ClusterIP`, `LoadBalancer` і `NGINX Ingress` (`/` та `/db`)[cite: 9, 18, 19].
* **Автоматизація та CI/CD (Найвищий рівень):** Bash-скрипт `scripts/deploy.sh` для повного розгортання кластера однією командою та пайплайн `.github/workflows/k8s-deploy.yml` для автоматичної перевірки збірки, деплою й Smoke Test при кожному `push` у `main`[cite: 10].

## Структура репозиторію

```text
├── .github/
│   └── workflows/
│       └── k8s-deploy.yml        # CI/CD пайплайн GitHub Actions
├── app/                          # Мікросервіс FastAPI
│   ├── Dockerfile                # Інструкція збірки образу fastapi-app:v1
│   ├── main.py                   # Вихідний код REST API
│   └── requirements.txt          # Залежності контейнера FastAPI
├── k8s/                          # Маніфести Kubernetes за рівнями складності
│   ├── middle-level/             # Один под (emptyDir + NodePort)
│   └── high-level/               # Окремі поди (PV/PVC + ConfigMap + Ingress/LoadBalancer)
├── scripts/
│   └── deploy.sh                 # Bash-скрипт автоматичного розгортання
├── .gitattributes                
├── .gitignore                    
├── host_monitoring_agent.py      # Клієнтський агент збору метрик CPU на хості
├── README.md                     
└── requirements.txt              # Залежності для локального агента моніторингу              