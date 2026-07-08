# Przewodnik Setupu Oracle Cloud — dla właściciela

Ten dokument jest **step-by-step instrukcją** dla osoby, która będzie konfigurować Oracle Cloud VPS. Wszystkie komendy terminal'u są gotowe do skopiowania i wklejenia.

## Faza 1: Rejestracja Oracle Cloud (30 min)

### 1.1 Utwórz konto
- Strona: https://www.oracle.com/cloud/free/
- Wymagane: email, payment method (tylko autoryzacja, nie obciążenie)
- Potwierdź email

### 1.2 Provisioning VPS

W Oracle Cloud Console:
1. **Compute → Instances → Create Instance**
2. **Image:** Canonical Ubuntu 22.04 LTS
3. **Shape:** 
   - Preferowana: Ampere (A1 Compute, 4 OCPU, 24 GB RAM) — zawsze free
   - Fallback: VM.Standard.E5.Flex (może być na trial $300/30 dni)
4. **Storage:** 50 GB (default)
5. **SSH Key:** Upload swojego public key

**Jak wygenerować klucz SSH (jeśli nie masz):**
```bash
# Na swoim komputerze
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oracle_key
cat ~/.ssh/oracle_key.pub  # skopiuj to do Oracle Console
```

6. **Firewall Rules:** Po utworzeniu instancji:
   - Subnet → Security List
   - Add Ingress Rules:
     - Port 22 (SSH): 0.0.0.0/0
     - Port 80 (HTTP): 0.0.0.0/0
     - Port 443 (HTTPS): 0.0.0.0/0

**Zanotuj:** public IP adres instancji (np. `123.45.67.89`)

---

## Faza 2: Podstawowa konfiguracja (30 min)

### 2.1 Połącz SSH do VPS

```bash
ssh -i ~/.ssh/oracle_key ubuntu@<PUBLIC_IP>
```

Zaakceptuj fingerprint, wpisujesz `yes`.

### 2.2 Zaktualizuj system

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git
```

### 2.3 Zainstaluj Docker

```bash
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

### 2.4 Zainstaluj Docker Compose

```bash
sudo apt install -y docker-compose
docker-compose --version
```

---

## Faza 3: Deployment aplikacji (30 min)

### 3.1 Clone repo

```bash
# Przejdź do home
cd ~

# Clone sklepik
git clone https://github.com/pawelekbyra/sklepik.git
cd sklepik
```

### 3.2 Przygotuj zmienne środowiskowe

```bash
# Skopiuj template
cp .env.example .env

# Edytuj (wstaw rzeczywiste wartości)
nano .env
```

**Minimalne zmienne do ustawienia:**
```
POSTGRES_PASSWORD=<silne hasło>
SECRET_KEY_BASE=<wygeneruj: rails secret>
RAILS_ENV=production
CDN_HOST=https://<twoja domena>
```

Wyjdź: Ctrl+X → Y → Enter

### 3.3 Utwórz foldery SSL (Let's Encrypt)

```bash
sudo mkdir -p /etc/letsencrypt/live/kakaowy-sklepik.com
sudo chown -R $USER:$USER /etc/letsencrypt
mkdir -p ./ssl
```

### 3.4 Pierwsza certyfikacja (Let's Encrypt)

```bash
sudo apt install -y certbot

sudo certbot certonly --standalone \
  -d kakaowy-sklepik.com \
  -d www.kakaowy-sklepik.com \
  --email admin@example.com \
  --agree-tos \
  --non-interactive

# Copy certs do folderu nginx
sudo cp /etc/letsencrypt/live/kakaowy-sklepik.com/fullchain.pem ./ssl/cert.pem
sudo cp /etc/letsencrypt/live/kakaowy-sklepik.com/privkey.pem ./ssl/key.pem
sudo chown -R $USER:$USER ./ssl
```

**Jeśli nie masz własnej domeny:** użyj wildcard z Let's Encrypt albo certyfikat self-signed (dla development):
```bash
openssl req -x509 -newkey rsa:4096 -keyout ./ssl/key.pem -out ./ssl/cert.pem -days 365 -nodes
```

### 3.5 Uruchom Docker Compose

```bash
# Zaloguj się do GitHub Container Registry
# (jeśli repo jest private, użyj token'u)
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Build i uruchom stack
docker-compose build
docker-compose up -d

# Sprawdź logi
docker-compose logs -f web
```

### 3.6 Zweryfikuj deployment

```bash
# Health check
curl http://localhost:3000/up

# Logi aplikacji
docker-compose logs web

# Status kontenerów
docker-compose ps
```

Jeśli coś źle — sprawdź logi: `docker-compose logs <service_name>`

---

## Faza 4: Automatyczny deploy z GitHub Actions (10 min)

### 4.1 Dodaj secrets do GitHub repo

W repo settings → Secrets:

1. **ORACLE_HOST** = `123.45.67.89` (public IP)
2. **ORACLE_SSH_KEY** = zawartość `~/.ssh/oracle_key` (private key!!)
   ```bash
   cat ~/.ssh/oracle_key | pbcopy  # macOS
   # lub na Windows: Get-Content ~/.ssh/oracle_key | Set-Clipboard
   ```

### 4.2 Test deploymentu

Push do `main` branch:
```bash
git add .
git commit -m "Oracle Cloud deployment configuration"
git push origin main
```

GitHub Actions powinien automatycznie:
1. Buildować Docker image
2. Pushować do GHCR
3. SSH się do Oracle
4. Pullować image i uruchomić `docker-compose up`

Monitoring: https://github.com/pawelekbyra/sklepik/actions

---

## Faza 5: Backup & Monitoring (opcjonalne)

### 5.1 Daily backup bazy danych

```bash
# Create backup script
cat > ~/backup-db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
cd ~/sklepik
docker-compose exec -T postgres pg_dump -U postgres spree_production | gzip > $BACKUP_DIR/db_$TIMESTAMP.sql.gz
find $BACKUP_DIR -mtime +7 -delete  # Keep last 7 days
EOF

chmod +x ~/backup-db.sh

# Add to crontab
crontab -e
# Add line: 0 2 * * * ~/backup-db.sh
```

### 5.2 Monitoring (opcjonalnie)

```bash
# Check disk usage
df -h

# Check memory
free -h

# Check Docker processes
docker stats

# Tail logs
docker-compose logs -f
```

---

## Troubleshooting

| Problem | Rozwiązanie |
|---|---|
| SSH nie łączy | Sprawdź security list firewall w Oracle Console; `ssh -vvv` dla debug |
| Docker compose nie start | Sprawdź: `docker-compose config`, `docker-compose logs` |
| Baza nie migruje | `docker-compose exec web bundle exec rake db:migrate` manual |
| 500 errors z Rails | `docker-compose logs web` → szukaj stacktrace |
| Certifikat SSL expires | `sudo certbot renew` (crontab powinien robić auto) |
| Brak dostępu do obrazu GHCR | `docker login ghcr.io` z GitHub token |

---

## Rollback (jeśli coś pójdzie źle)

```bash
# Stop everything
docker-compose down

# Revert git
git reset --hard HEAD~1

# Restart
docker-compose up -d
```

---

## Następne kroki

1. **Właściciel:** Wykonaj Faza 1-3 powyżej
2. **CI/CD:** GitHub Actions obsługuje deployment automatycznie (Faza 4)
3. **Monitoring:** Skonfiguruj backup (Faza 5, opcjonalnie)
4. **DNS:** Wskaż domenę na Oracle IP (konfiguracja domeny, poza zakresem repo)

---

## Automatyzacja: Jak to działa na przyszłość

Po skonfigurowaniu powyższego, **deployment jest całkowicie zautomatyzowany**. Nie musisz już nic robić ręcznie.

### Jak działa na przyszłość?

```
Ty robisz zmianę w kodzie
    ↓
git push origin main
    ↓
GitHub Actions uruchamia się AUTOMATYCZNIE
    ↓
1. Builduje Docker image
2. Pushuje do GitHub Container Registry (GHCR)
3. SSH się do Oracle VPS
4. Pulluje obraz i uruchamia docker-compose up
5. Migruje bazę danych
6. Health check
    ↓
✓ Aplikacja wdrażana — ty nic nie robisz
```

### Bezpieczeństwo kluczy SSH

**Klucze SSH NIGDY nie są w repozytorium:**
- Klucz prywatny (`ssh-key-2026-07-08.key`) — trzymasz u siebie lokalnie w `~/.ssh/`
- GitHub ma kopię w **Secrets** (Ustawienia → Secrets) — niedostępne publicznie
- GitHub Actions automatycznie używa `ORACLE_SSH_KEY` do SSH na Oracle

**Nie udostępniaj klucza nikomu.**

### Monitoring deployów

Możesz obserwować deployment w:
```
https://github.com/pawelekbyra/sklepik/actions
```

Tam widzisz:
- ✓ Build succeeded
- ✓ Push to registry successful
- ✓ Deploy to Oracle successful
- Lub ✗ błędy (jeśli coś poszło nie tak)

### Następny deploy — co robisz:

1. Robisz zmianę w kodzie
2. Commitasz i pushasz do `main`
3. GitHub Actions robi resztę — **siedź i czekaj**
4. Sprawdzisz w Actions tab czy deployment się powiódł

**To tyle. Nic więcej nie musisz robić.**

---

**Pytania?** Sprawdź `docs/deployment-oracle.md` dla więcej szczegółów na temat architektury.
