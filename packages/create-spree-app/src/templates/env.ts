export interface EnvPorts {
  web: number
  db: number
  meilisearch: number
}

export function envContent(secretKeyBase: string, ports: EnvPorts): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_PORT=${ports.web}
SPREE_DB_PORT=${ports.db}
SPREE_MEILISEARCH_PORT=${ports.meilisearch}
SPREE_VERSION_TAG=latest
`
}

export function storefrontEnvContent(port: number, apiKey?: string): string {
  return `SPREE_API_URL=http://localhost:${port}
SPREE_PUBLISHABLE_KEY=${apiKey ?? 'pk_REPLACE_ME_AFTER_DOCKER_START'}
`
}
