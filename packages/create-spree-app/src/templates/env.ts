/**
 * The project root `.env`: Rails secret, backend port, image tag, and the
 * persisted sample-data choice (`SPREE_SAMPLE_DATA`) that first-run setup
 * reads back when it runs deferred (through `spree dev`).
 */
export function envContent(secretKeyBase: string, port: number, sampleData: boolean): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_PORT=${port}
SPREE_VERSION_TAG=latest
# Whether first-run setup loads demo products and orders.
SPREE_SAMPLE_DATA=${sampleData}
`
}

export function storefrontEnvContent(port: number, wholesale = false): string {
  let content = `SPREE_API_URL=http://localhost:${port}
SPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START
`
  if (wholesale) {
    content += `
# Wholesale B2B portal (/wholesale) — the gated channel and trade price list
# ship with sample data. Buyers self-register; approve one by adding them to
# the "Wholesale" customer group in the admin. The portal uses
# SPREE_PUBLISHABLE_KEY (the channel header selects the channel); set
# SPREE_WHOLESALE_PUBLISHABLE_KEY only to pin a channel-bound key.
SPREE_WHOLESALE_CHANNEL=wholesale
`
  }
  return content
}
