import type { EncryptionKeys } from '../utils.js'

/**
 * The project root `.env`: Rails secrets, ports and image tag. The Mailpit
 * ports are written even when they are the defaults, so compose never falls
 * back to a value the scaffold did not check was free.
 */
export function envContent(
  secretKeyBase: string,
  port: number,
  mailpitSmtpPort: number,
  mailpitUiPort: number,
  encryptionKeys: EncryptionKeys,
): string {
  return `SECRET_KEY_BASE=${secretKeyBase}
# Active Record encryption — Spree encrypts webhook signing keys, gateway
# customer ids and OAuth tokens with these. Back them up and never change them
# once data is encrypted; use a separate set in production.
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${encryptionKeys.primaryKey}
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${encryptionKeys.deterministicKey}
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${encryptionKeys.keyDerivationSalt}
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
