/**
 * The project root `.env`: Rails secret, ports and image tag. The Mailpit
 * ports are written even when they are the defaults, so compose never falls
 * back to a value the scaffold did not check was free.
 */
export function envContent(
  secretKeyBase: string,
  port: number,
  mailpitSmtpPort: number,
  mailpitUiPort: number,
): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
SPREE_PORT=${port}
SPREE_VERSION_TAG=latest
MAILPIT_SMTP_PORT=${mailpitSmtpPort}
MAILPIT_UI_PORT=${mailpitUiPort}
`
}

export function storefrontEnvContent(port: number): string {
  const content = `SPREE_API_URL=http://localhost:${port}
SPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START
`
  return content
}
