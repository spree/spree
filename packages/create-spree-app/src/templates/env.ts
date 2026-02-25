import { SPREE_PORT, SPREE_VERSION_TAG } from '../constants.js'

export function envContent(secretKeyBase: string): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_VERSION_TAG=${SPREE_VERSION_TAG}
`
}

export function storefrontEnvContent(apiKey?: string): string {
  return `NEXT_PUBLIC_SPREE_API_URL=http://localhost:${SPREE_PORT}
NEXT_PUBLIC_SPREE_PUBLISHABLE_KEY=${apiKey ?? 'pk_REPLACE_ME_AFTER_DOCKER_START'}
`
}
