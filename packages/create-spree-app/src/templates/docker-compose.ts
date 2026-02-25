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
    environment:
      DATABASE_HOST: postgres
      SECRET_KEY_BASE: \${SECRET_KEY_BASE}
      RAILS_ENV: production
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
