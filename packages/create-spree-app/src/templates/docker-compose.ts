import { SPREE_IMAGE, SPREE_VERSION_TAG } from '../constants.js'

export function dockerComposeContent(): string {
  return `services:
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

  spree:
    image: ${SPREE_IMAGE}:${SPREE_VERSION_TAG}
    depends_on:
      postgres:
        condition: service_healthy
    env_file: .env
    environment:
      DATABASE_URL: postgres://postgres@postgres:5432/spree_production
      CACHE_DATABASE_URL: postgres://postgres@postgres:5432/spree_production_cache
      QUEUE_DATABASE_URL: postgres://postgres@postgres:5432/spree_production_queue
      CABLE_DATABASE_URL: postgres://postgres@postgres:5432/spree_production_cable
      RAILS_ENV: production
      RAILS_FORCE_SSL: "false"
      RAILS_ASSUME_SSL: "false"
      RAILS_LOG_TO_STDOUT: "true"
    ports:
      - "3000:3000"
    healthcheck:
      test: curl -f http://localhost:3000/up || exit 1
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

volumes:
  postgres_data:
`
}
