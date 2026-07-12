export function envContent(secretKeyBase: string, port: number): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_PORT=${port}
SPREE_VERSION_TAG=latest
`
}

export function storefrontEnvContent(port: number, apiKey?: string): string {
  return `SPREE_API_URL=http://localhost:${port}
SPREE_PUBLISHABLE_KEY=${apiKey ?? 'pk_REPLACE_ME_AFTER_DOCKER_START'}
`
}

export function dashboardEnvContent(port: number): string {
  return `# URL of your Spree API server. No credentials belong in this file —
# every VITE_-prefixed value is compiled into the client bundle.
VITE_SPREE_API_URL=http://localhost:${port}
`
}
