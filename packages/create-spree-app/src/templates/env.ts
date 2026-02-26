import { SPREE_VERSION_TAG } from '../constants.js'

export function envContent(secretKeyBase: string, port: number): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_PORT=${port}
SPREE_VERSION_TAG=${SPREE_VERSION_TAG}
`
}

export function storefrontEnvContent(port: number, apiKey?: string): string {
  return `SPREE_API_URL=http://localhost:${port}
SPREE_PUBLISHABLE_KEY=${apiKey ?? 'pk_REPLACE_ME_AFTER_DOCKER_START'}
`
}
