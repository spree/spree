# Deployment backendu na Oracle Cloud Always Free

**Status:** Dokumentacja w przygotowaniu. Ten dokument opisuje **docelową** architekturę i proces migracji z Render na Oracle Cloud VPS. Po zakończeniu migracji ten plik zawierać będzie faktyczne parametry i procedury.

## Dlaczego Oracle Cloud Always Free?

| Kryterium | Render free | Render Starter ($7/mo) | Oracle Always Free | Oracle Standard |
|---|---|---|---|---|
| RAM | 512 MB | 512 MB | 1-2 GB | 2-12 GB |
| vCPU | Shared | Shared | 2 core (ARM) | 2-4 core |
| Storage | 0.5 GB | 0.5 GB | 20 GB | 100+ GB |
| Koszt | 0 zł | ~30 zł | 0 zł | $0.01-0.04/h |
| Problem | OOM crashes | OOM crashes | Brak | Skalowalna |

**Decyzja:** Render nie rozwiązuje OOM w tier $7, trzeba Standard ($25+/mo). Oracle Always Free daje wystarczające zasoby bez kosztów, z opcją skalowania jeśli będzie potrzeba.

## Architektura docelowa

```
┌─────────────────────────────────────────────────────────┐
│ Oracle Cloud Always Free VPS (Ampere A1 lub VM.Standard) │
├─────────────────────────────────────────────────────────┤
│ Operating System: Ubuntu 22.04 LTS                       │
├─────────────────────────────────────────────────────────┤
│ Docker Container Stack:                                  │
│  ├─ PostgreSQL 15 (database)                             │
│  ├─ Redis 7 (cache + Sidekiq queue)                      │
│  ├─ Rails + Puma (web server, port 3000 internal)        │
│  ├─ Sidekiq (background worker, disabled on Render)      │
│  └─ Nginx (reverse proxy, port 80/443 public)            │
├─────────────────────────────────────────────────────────┤
│ SSL/TLS: Let's Encrypt (auto-renewal via certbot)        │
│ Domain: TBD (currently *.vercel.app / *.onrender.com)    │
├─────────────────────────────────────────────────────────┤
│ Deployment: GitHub Actions → SSH → `docker compose up`  │
│ Backups: Daily PostgreSQL dump → S3 / R2                 │
└─────────────────────────────────────────────────────────┘
```

## Porównanie Render vs Oracle

| Aspekt | Render | Oracle |
|---|---|---|
| **Server bootstrap** | Automatic (blueprint) | Manual (terraform/scripts) |
| **Build & Release** | `buildCommand` → `preDeployCommand` → `startCommand` | Single: Docker build + push → SSH pull + `compose up` |
| **App freshness** | `server/` jest świeży za każdym razem | `server/` jest trwały (commitowany w repo) |
| **Migration timestamps** | Kopiowanie migracji z gem → nowe timestampy → ryzyko duplikatów | Jeden raz zsynchronizowane (F15 "migrate idempotently") |
| **Sidekiq worker** | Zakomentowany (wymaga płatnego planu) | Włączony (zasoby dostępne) |
| **Cold start** | ~18s po 15 min bezczynności | 0s (zawsze running) |
| **Scaling** | Możliwe, ale trzeba płacić | Możliwe na Oracle Standard tier |
| **Downtime przy deploy** | ~2 min (build + release) | ~10-30 s (compose pull + restart) |

## Kroki migracji (high-level)

### Faza 1: Przygotowanie (Cloud Session)
1. Aktualizacja `docs/deployment-oracle.md` (ten plik)
2. Utworzenie `docker-compose.yml` z PostgreSQL, Redis, Rails, Sidekiq, Nginx
3. Przygotowanie skryptów deploy'u (GitHub Actions workflow)
4. Testowanie stack'u lokalnie w Docker

### Faza 2: Oracle Cloud Setup (Local Machine with SSH)
1. Rejestracja konta Oracle Cloud
2. Provisioning VPS (Ampere A1 lub VM.Standard.E5)
3. SSH public key setup
4. Initial security (firewall, fail2ban, automatic updates)
5. Docker installation
6. DNS configuration

### Faza 3: Initial Deployment (Local Machine)
1. SSH do VPS
2. Clone repo, set env vars
3. `docker compose build && docker compose up -d`
4. Zapora/Nginx SSL setup (Let's Encrypt)
5. Verify `/up` health check

### Faza 4: Gradual Cutover
1. Czytanie traffic'u z Render, gromadzenie metryk
2. Health check na Oracle (internal + via LoadBalancer)
3. DNS cname switch (jeśli ma własną domenę)
4. Monitorowanie przez 24-48 h

## Szczegłowy guide — będzie uzupełniony

### 1. Oracle Cloud Account & VPS Setup

**1.1 Rejestracja** (do zrobienia lokalnie)
- Strona: https://www.oracle.com/cloud/free/
- Wymagane: email, payment method (autoryzacja, nie obciążenie)
- Aktywacja: ~10-20 min

**1.2 Provisioning VPS**
```
Compute → Instances → Create Instance
  - Image: Canonical Ubuntu 22.04 LTS
  - Shape: Ampere (A1 Compute, 4 OCPU, 24 GB RAM) — jeśli dostępny
    Fallback: VM.Standard.E5.Flex (starszy, może być na trial $300/30 dni)
  - Storage: 50 GB (default)
  - Network: Default VCN
  - SSH public key: upload `~/.ssh/id_rsa.pub` (wygenerować lokalnie `ssh-keygen`)
```

**1.3 Firewall** (Security List na Oracle Console)
```
Ingress Rules:
  - Port 22 (SSH): 0.0.0.0/0 (ograniczyć do swojego IP jeśli znany)
  - Port 80 (HTTP): 0.0.0.0/0
  - Port 443 (HTTPS): 0.0.0.0/0
  - Port 3000 (Rails, internal): 0.0.0.0/0 (potem Nginx proxy)
```

### 2. Docker & Docker Compose Setup

**2.1 SSH do VPS**
```bash
ssh -i ~/.ssh/oracle_key ubuntu@<public_ip>
```

**2.2 Install Docker** (na Ubuntu)
```bash
# Zaktualizuj system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker run hello-world
```

**2.3 Install Docker Compose**
```bash
sudo apt install -y docker-compose
docker-compose --version
```

### 3. Application Setup (docker-compose.yml)

Zamiast Puma/Sidekiq jako osobne procesy, wszystko w kontenerach. `docker-compose.yml` będzie w repo root (lub `server/docker-compose.yml`).

**Struktura:**
```yaml
version: '3.9'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: spree_production
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  web:
    build:
      context: .
      dockerfile: server/Dockerfile
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/spree_production
      REDIS_URL: redis://redis:6379/1
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      # ... inne zmienne (SPREE_PATH, CDN_HOST, itd.)
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "3000:3000"
    volumes:
      - ./public:/app/public  # Assets mount
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/up"]
      interval: 30s
      timeout: 10s
      retries: 3

  sidekiq:
    build:
      context: .
      dockerfile: server/Dockerfile
    command: bundle exec sidekiq -c 5 -v
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/spree_production
      REDIS_URL: redis://redis:6379/1
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
    depends_on:
      - postgres
      - redis
    volumes:
      - ./log:/app/log

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro  # Let's Encrypt certs
      - ./public:/app/public:ro
    depends_on:
      - web
    healthcheck:
      test: ["CMD", "wget", "-q", "-O-", "http://localhost/up"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

### 4. Dockerfile (Rails + Sidekiq)

`server/Dockerfile` — multi-stage, wspólny dla `web` i `sidekiq`:

```dockerfile
FROM ruby:3.3.6-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-client \
    libpq-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile(s) from monorepo gems
COPY spree/ /spree/
COPY server/Gemfile* ./
COPY server/.ruby-version ./

# Bundle install
ENV BUNDLE_GEMFILE=/app/Gemfile
ENV SPREE_PATH=/spree
RUN bundle install --without development test

# Copy application
COPY server/ ./

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:precompile

# Default command (can be overridden)
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### 5. Nginx Configuration

`nginx.conf` — reverse proxy + SSL termination:

```nginx
upstream rails {
  server web:3000;
}

server {
  listen 80;
  server_name _;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  server_name _;

  ssl_certificate /etc/nginx/ssl/cert.pem;
  ssl_certificate_key /etc/nginx/ssl/key.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;

  client_max_body_size 100M;

  location / {
    proxy_pass http://rails;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 60s;
  }

  location /up {
    proxy_pass http://rails;
    access_log off;
  }
}
```

### 6. GitHub Actions Deployment

`.github/workflows/deploy-oracle.yml` — automatyczny deploy przy pushu do main:

```yaml
name: Deploy to Oracle Cloud

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/spree-backend

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest -f server/Dockerfile .

      - name: Push to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ${{ env.REGISTRY }} -u ${{ github.actor }} --password-stdin
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

      - name: Deploy to Oracle Cloud
        env:
          SSH_PRIVATE_KEY: ${{ secrets.ORACLE_SSH_KEY }}
          ORACLE_HOST: ${{ secrets.ORACLE_HOST }}
          ORACLE_USER: ubuntu
        run: |
          mkdir -p ~/.ssh
          echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          ssh-keyscan -H $ORACLE_HOST >> ~/.ssh/known_hosts

          # Pull latest image and restart
          ssh $ORACLE_USER@$ORACLE_HOST << 'EOF'
            cd ~/sklepik
            git pull origin main
            docker-compose pull
            docker-compose up -d --no-deps --build web sidekiq
            docker-compose exec -T web bundle exec rake db:migrate
          EOF
```

### 7. Let's Encrypt SSL Setup

Na VPS, przy pierwszym uruchomieniu:

```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Generate cert (jeden raz)
sudo certbot certonly --standalone \
  -d kakaowy-sklepik.com \
  -d www.kakaowy-sklepik.com \
  --email admin@example.com \
  --agree-tos

# Certy lądują w /etc/letsencrypt/live/
# Nginx.conf powinien wskazywać na:
# /etc/letsencrypt/live/kakaowy-sklepik.com/fullchain.pem
# /etc/letsencrypt/live/kakaowy-sklepik.com/privkey.pem

# Auto-renew (crontab)
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### 8. Backups

Daily PostgreSQL dump do S3/R2:

```bash
# Crontab on VPS
0 2 * * * docker-compose exec -T postgres pg_dump -U postgres spree_production | \
  gzip | \
  aws s3 cp - s3://backups-sklepik/$(date +\%Y-\%m-\%d).sql.gz
```

### 9. Monitoring & Logs

```bash
# Tail logs na VPS
docker-compose logs -f web

# Check health
curl https://kakaowy-sklepik.com/up

# Database connections
docker-compose exec -T postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Sidekiq stats
docker-compose exec web bundle exec sidekiq-cli info
```

## Checklist migracji

- [ ] Oracle Cloud account created
- [ ] VPS provisioned (IP noted)
- [ ] SSH key configured
- [ ] Firewall rules set
- [ ] Docker + Compose installed on VPS
- [ ] `docker-compose.yml` created & tested locally
- [ ] `server/Dockerfile` created
- [ ] `nginx.conf` created
- [ ] GitHub Actions workflow created
- [ ] `.env.production` secured in GitHub Secrets
- [ ] First deploy via GitHub Actions successful
- [ ] Health check `/up` responding
- [ ] Migrations ran successfully
- [ ] SSL cert installed (Let's Encrypt)
- [ ] Sidekiq workers processing jobs
- [ ] Backup cron configured
- [ ] DNS switch (if custom domain)
- [ ] Monitoring alerts setup

## Znane ryzyko & mitygacja

| Ryzyko | Mitygacja |
|---|---|
| **Always Free brak dostępu (Oracle Out of Capacity)** | Fallback na VM.Standard.E5 (trial $300/30 dni); dokumentacja; plan upgrade na Standard |
| **Efemeryczne `server/` na Render → trwałe na Oracle** | Migracja wymaga `git add server/`, commitów migracji itp. (plan F15) |
| **SSH key loss** | Backup klucza; Oracle console password recovery |
| **Database corruption** | Daily backups na S3; punkt recovery 24h |
| **DDoS / brute force SSH** | fail2ban, rate limiting, IP whitelist jeśli znany |

## Następne kroki

1. **Właściciel:** Registracja Oracle Cloud, provisioning VPS (robiony poza repo)
2. **Cloud Session:** Finalizacja `docker-compose.yml`, Dockerfile, GitHub Actions
3. **Local Session:** SSH do VPS, zainstalowanie Docker, first deploy
4. **Staging:** 24-48h weryfikacji stabilności
5. **Cutover:** DNS switch (jeśli ma domenę)
6. **Post-mortem:** Dokumentacja wyciągniętych lekcji w `docs/lessons-learned.md`

---

**Ostatnia aktualizacja:** 2026-07-08  
**Status:** Draft (awaiting Oracle provisioning & local testing)
