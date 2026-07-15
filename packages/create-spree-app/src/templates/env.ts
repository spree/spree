export function envContent(secretKeyBase: string, port: number, sampleData: boolean): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_PORT=${port}
SPREE_VERSION_TAG=latest
# Whether first-run setup loads demo products and orders.
SPREE_SAMPLE_DATA=${sampleData}
`
}

export function storefrontEnvContent(port: number, apiKey?: string): string {
  return `SPREE_API_URL=http://localhost:${port}
SPREE_PUBLISHABLE_KEY=${apiKey ?? 'pk_REPLACE_ME_AFTER_DOCKER_START'}
`
}
