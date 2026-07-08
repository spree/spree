#!/bin/bash
set -e

echo "=== Oracle Cloud Deployment Script ==="
echo "This script sets up Docker, Docker Compose, and deploys Kakałowy Sklepik"
echo ""

# Step 1: Add user to docker group
echo "Step 1: Configuring Docker for ubuntu user..."
sudo usermod -aG docker $USER
newgrp docker

# Step 2: Verify Docker
echo "Step 2: Verifying Docker installation..."
docker --version
docker run hello-world

# Step 3: Install Docker Compose
echo "Step 3: Installing Docker Compose..."
sudo apt install -y docker-compose
docker-compose --version

# Step 4: Create directories
echo "Step 4: Creating necessary directories..."
mkdir -p ~/sklepik
mkdir -p /etc/letsencrypt/live/kakaowy-sklepik.com
sudo chown -R $USER:$USER /etc/letsencrypt
mkdir -p ~/sklepik/ssl

# Step 5: Clone repository
echo "Step 5: Cloning repository..."
cd ~
if [ -d "sklepik" ]; then
  cd sklepik
  git fetch origin
  git checkout main
  git pull origin main
else
  git clone https://github.com/pawelekbyra/sklepik.git
  cd sklepik
fi

# Step 6: Copy environment template
echo "Step 6: Setting up environment variables..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "⚠️  .env file created from template. Please edit it with your values:"
  echo "   nano .env"
  echo ""
  echo "Required variables:"
  echo "  - POSTGRES_PASSWORD (strong password)"
  echo "  - SECRET_KEY_BASE (run: rails secret)"
  echo "  - RAILS_ENV=production"
  echo "  - CDN_HOST (your domain)"
fi

# Step 7: Create SSL certificate (self-signed for now)
echo "Step 7: Creating SSL certificate..."
if [ ! -f ./ssl/cert.pem ]; then
  openssl req -x509 -newkey rsa:4096 -keyout ./ssl/key.pem -out ./ssl/cert.pem \
    -days 365 -nodes -subj "/CN=localhost"
  echo "✓ Self-signed SSL certificate created"
  echo "  (Replace with Let's Encrypt certificate for production)"
fi

# Step 8: Build and start containers
echo "Step 8: Building and starting Docker containers..."
docker-compose build
docker-compose up -d

# Step 9: Wait for services to be ready
echo "Step 9: Waiting for services to be ready..."
sleep 10

# Step 10: Run migrations
echo "Step 10: Running database migrations..."
docker-compose exec -T web bundle exec rake spree:install:migrations || true
docker-compose exec -T web bundle exec rake db:migrate || true
docker-compose exec -T web bundle exec rake spree:role_users:backfill_store_ids || true
docker-compose exec -T web bundle exec rake db:seed || true

# Step 11: Health check
echo "Step 11: Health check..."
if curl -f http://localhost:3000/up; then
  echo "✓ Application is healthy!"
else
  echo "⚠️  Health check failed. Check logs: docker-compose logs web"
fi

# Step 12: Display status
echo ""
echo "=== Deployment Complete ==="
echo "✓ Docker installed and configured"
echo "✓ Repository cloned"
echo "✓ Containers running"
echo ""
echo "Next steps:"
echo "1. Edit .env file with production values: nano .env"
echo "2. For Let's Encrypt SSL: certbot certonly --standalone -d your-domain.com"
echo "3. Copy SSL certificates: cp /etc/letsencrypt/live/your-domain/fullchain.pem ./ssl/cert.pem"
echo "4. Restart nginx: docker-compose restart nginx"
echo ""
echo "View logs:"
echo "  docker-compose logs -f web      # Rails app"
echo "  docker-compose logs -f nginx    # Nginx"
echo "  docker-compose ps               # Container status"
echo ""
echo "Access your app at: https://141.253.103.172"
echo "(Replace IP with your domain in production)"
