# Multi-Container Application Deployment in Kubernetes (FastAPI + SQLite-web)

Практичний проєкт із розгортання багатоконтейнерної клієнт-серверної системи моніторингу ресурсів ПК на базі **FastAPI**, **SQLite-web** та Python-агента у локальному кластері **Kubernetes (Minikube)** з автоматизацією розгортання та CI/CD-пайплайном **GitHub Actions**.

## Зміст
1. [Архітектура системи](#архітектура-системи)
2. [Структура репозиторію](#структура-репозиторію)
3. [Попередні вимоги](#попередні-вимоги)
4. [Інструкція з розгортання (Deployment Guide)](#інструкція-з-розгортання-deployment-guide)
5. [Доступ до сервісів та перевірка роботи](#доступ-до-сервісів-та-перевірка-роботи)
6. [Запуск клієнтського агента моніторингу](#запуск-клієнтського-агента-моніторингу)
7. [CI/CD та автоматичне тестування](#cicd-та-автоматичне-тестування)
8. [Зупинка та очищення ресурсів](#зупинка-та-очищення-ресурсів)

---

## Архітектура системи

Система складається з трьох взаємопов'язаних компонентів:
* **Host Monitoring Agent (`host_monitoring_agent.py`):** неконтейнеризований клієнтський скрипт на хост-машині, який періодично зчитує завантаження CPU та надсилає метрики через HTTP `POST /metrics`.
* **Backend (`FastAPI`):** REST API сервіс (`app/main.py`), запакований у власний Docker-образ `fastapi-app:v1`, який приймає метрики (`POST /metrics`), повертає історію записів (`GET /metrics`), видаляє записи (`DELETE /metrics/{id}`) та зберігає їх у базу даних SQLite.
* **Database UI (`SQLite-web`):** вебінтерфейс (`coleifer/sqlite-web:latest`) для перегляду та редагування таблиць бази даних `app.db` у браузері.

### Реалізовані рівні оркестрації (`k8s/`)
* **Середній рівень (`k8s/middle-level/`):** розгортання обох контейнерів (`fastapi-app` та `sqlite-web`) у межах **одного пода** (`monitoring-deployment`), обмін файлом бази даних через тимчасовий том `emptyDir` та публікація портів (`8000`, `8080`) через сервіс типу `NodePort`.
* **Високий рівень (`k8s/high-level/`):** мікросервісна архітектура з розділенням на **незалежні поди** (`fastapi-deployment` та `sqlite-web-deployment`), персистентним збереженням даних на рівні ноди у `PersistentVolume` (`hostPath` `/mnt/data/monitoring`) через `PersistentVolumeClaim`, централізованою конфігурацією в `ConfigMap` та маршрутизацією трафіку через `ClusterIP`, `LoadBalancer` і єдину точку входу `NGINX Ingress` (`/` та `/db`).
* **Найвищий рівень (Автоматизація та CI/CD):** Bash-скрипт `scripts/deploy.sh` для повного автоматичного розгортання інфраструктури однією командою та пайплайн `.github/workflows/k8s-deploy.yml` у GitHub Actions для автоматичної перевірки збірки, деплою й Smoke Test при кожному `push`.

---

## Структура репозиторію

```text
├── .github/
│   └── workflows/
│       └── k8s-deploy.yml        # CI/CD пайплайн GitHub Actions
├── app/                          # Мікросервіс FastAPI
│   ├── Dockerfile                # Інструкція збірки образу fastapi-app:v1
│   ├── main.py                   # Вихідний код REST API
│   └── requirements.txt          # Залежності контейнера FastAPI
├── k8s/                          # Декларативні маніфести Kubernetes
│   ├── middle-level/             # Один под (emptyDir + NodePort)
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── high-level/               # Окремі поди (PV/PVC + ConfigMap + Ingress/LoadBalancer)
│       ├── configmap.yaml
│       ├── deployments.yaml
│       ├── ingress.yaml
│       ├── services.yaml
│       └── storage.yaml
├── scripts/
│   └── deploy.sh                 # Bash-скрипт автоматичного розгортання (High-Level)
├── .gitattributes                # Фіксація переносів рядків LF для .sh скриптів
├── .gitignore                    # Виключення локального оточення (venv) та тимчасових файлів
├── host_monitoring_agent.py      # Клієнтський агент збору метрик CPU на хості
├── README.md                     # Документація проєкту
└── requirements.txt              # Залежності для локального агента моніторингу
```

---

## Попередні вимоги

Для локального запуску необхідні встановлені інструменти:
* **Docker Desktop** (або Docker Engine)
* **Minikube** (`v1.39+`)
* **kubectl** (`v1.31+`)
* **Python 3.10+**
* **Git Bash** (для запуску `.sh` скриптів у Windows)

---

## Інструкція з розгортання (Deployment Guide)

### Крок 1. Клонування репозиторію та запуск кластера Minikube
```bash
git clone <URL_вашого_репозиторію>
cd DevOps_Project_2

minikube start --driver=docker
kubectl get nodes
```
Дочекайтеся статусу `Ready` для вузла `minikube`.

### Крок 2. Автоматичне розгортання High-Level архітектури (Рекомендований спосіб)
Виконайте Bash-скрипт у **Git Bash** (або Linux/macOS терміналі). Скрипт автоматично збере образ `fastapi-app:v1`, завантажить `coleifer/sqlite-web:latest`, імпортує обидва образи у внутрішнє сховище Minikube, увімкне аддон `ingress`, застосує всі маніфести з `k8s/high-level/` та дочекається готовності подів:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### Крок 3. Ручне розгортання Middle-Level (опціонально: один под + emptyDir)
Якщо потрібно розгорнути конфігурацію середнього рівня без скрипту:
```bash
docker build -t fastapi-app:v1 ./app
docker pull coleifer/sqlite-web:latest
minikube image load fastapi-app:v1
minikube image load coleifer/sqlite-web:latest

kubectl apply -f k8s/middle-level/
kubectl get pods,services
```
Для доступу прокиньте порти:
```bash
kubectl port-forward service/monitoring-service 8000:8000 8080:8080
```

---

## Доступ до сервісів та перевірка роботи

### 1. Відкриття зовнішнього доступу (`minikube tunnel`)
Оскільки Minikube працює в ізольованій мережі Docker, відкрийте **окреме вікно термінала** та запустіть тунель (не закривайте це вікно під час роботи з сервісами):
```bash
minikube tunnel
```

### 2. Вебінтерфейси у браузері
Після запуску тунелю сервіси доступні за адресами:
* **Через єдину точку входу NGINX Ingress (порт 80):**
  * FastAPI Swagger UI: `[http://127.0.0.1/docs](http://127.0.0.1/docs)`
  * SQLite-web (перегляд БД): `[http://127.0.0.1/db](http://127.0.0.1/db)`
* **Напряму через сервіси типу `LoadBalancer`:**
  * FastAPI Swagger UI: `[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)`
  * SQLite-web: `[http://127.0.0.1:8080/db](http://127.0.0.1:8080/db)`

### 3. Перевірка стану ресурсів кластера
```bash
kubectl get pods,deployments,replicasets,services,ingress,pv,pvc
```
Для моніторингу споживання CPU та RAM контейнерами:
```bash
minikube addons enable metrics-server
kubectl top pods --containers
```

---

## Запуск клієнтського агента моніторингу

Щоб розпочати автоматичний збір та відправку метрик завантаження процесора хост-машини у кластер Kubernetes:

```bash
python -m venv venv
# Активація у Windows (Git Bash):
source venv/Scripts/activate
# Активація у Linux/macOS:
# source venv/bin/activate

pip install -r requirements.txt
python host_monitoring_agent.py
```
Надсилання даних можна перевірити у вебінтерфейсі `[http://127.0.0.1/db](http://127.0.0.1/db)` (таблиця `metrics`) або через `GET [http://127.0.0.1/metrics](http://127.0.0.1/metrics)`.

---

## CI/CD та автоматичне тестування

У репозиторії налаштовано автоматичний пайплайн **GitHub Actions** (`.github/workflows/k8s-deploy.yml`), який запускається при кожному `push` у гілку `main`/`master` або вручну (`workflow_dispatch`):

1. **Ініціалізація середовища:** розгортання чистого однонодового кластера Minikube у хмарній віртуальній машині `ubuntu-latest`.
2. **Автоматичний деплой:** виконання скрипту `./scripts/deploy.sh` та контроль статусу розгортання (`kubectl rollout status`).
3. **Smoke Test:** прокидання тимчасового тунелю `kubectl port-forward service/fastapi-service-clusterip 8000:80` та перевірка працездатності API за допомогою `curl -f [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)` (`HTTP 200 OK`).

---

## Зупинка та очищення ресурсів

Для видалення розгорнутих об'єктів з кластера:
```bash
kubectl delete -f k8s/high-level/
```
Для повної зупинки кластера Minikube:
```bash
minikube stop
```              