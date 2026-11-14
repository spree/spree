import { createAdminClient } from '@spree/admin-sdk'
import type { Command } from 'commander'
import { type ResolvedCredentials, resolveCredentials } from '../config.js'

export interface CredentialFlags {
  profile?: string
  baseUrl?: string
  apiKey?: string
  storeId?: string
}

/** Credential flags shared by every command that hits the Admin API. */
export function withCredentialFlags(command: Command): Command {
  return command
    .option('--profile <name>', 'use a saved profile (see `spree auth`)')
    .option('--base-url <url>', 'store URL (overrides profile/env/project)')
    .option(
      '--api-key <key>',
      'secret API key (prefer SPREE_API_KEY — flags leak into shell history)',
    )
    .option('--store-id <id>', 'X-Spree-Store-Id for hosts serving multiple stores')
}

export type AdminClient = ReturnType<typeof createAdminClient>

/** An Admin API client from resolved credentials, the way every command builds one. */
export async function clientFor(
  flags: CredentialFlags,
): Promise<{ client: AdminClient; credentials: ResolvedCredentials }> {
  const credentials = await resolveCredentials({
    baseUrl: flags.baseUrl,
    apiKey: flags.apiKey,
    profile: flags.profile,
  })
  const client = createAdminClient({
    baseUrl: credentials.baseUrl,
    secretKey: credentials.apiKey,
    ...(flags.storeId ? { storeId: flags.storeId } : {}),
  })
  return { client, credentials }
}
