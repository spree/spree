import { SPREE_IMAGE, SPREE_VERSION_TAG } from '../constants.js'

export function dockerComposeContent(_port: number): string {
  return `x-app: &app
  image: ${SPREE_IMAGE}:${SPREE_VERSION_TAG}
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
  env_file: .env
  environment: &app-env
    DATABASE_HOST: postgres
    REDIS_URL: redis://redis:6379/0
    SMTP_HOST: mailpit
    SMTP_PORT: 1025
    RAILS_ENV: production
    RAILS_FORCE_SSL: "false"
    RAILS_ASSUME_SSL: "false"
    RAILS_LOG_TO_STDOUT: "true"

services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: pg_isready -U postgres
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: redis-cli ping
      interval: 5s
      timeout: 5s
      retries: 5

  mailpit:
    image: axllent/mailpit
    ports:
      - "8025:8025"
      - "1025:1025"

  web:
    <<: *app
    ports:
      - "\${SPREE_PORT:-3000}:3000"
    healthcheck:
      test: curl -f http://localhost:3000/up || exit 1
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  worker:
    <<: *app
    command: bundle exec sidekiq

volumes:
  postgres_data:
  redis_data:
`
}
