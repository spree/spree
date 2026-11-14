import { createAdminClient } from '@spree/admin-sdk'
import { mintApiKey } from '../config.js'
import type { AdminClient } from './client.js'

/**
 * Runs something against the project's own stack with a key minted for that
 * run and revoked when it ends, whether or not it succeeded. A revoke that
 * did not happen (Ctrl-C) must not block the next run, so the fixed name
 * supersedes any leftover key. Answers the run's result and whether the key
 * was revoked.
 */
export async function withTemporaryKey<Result>(
  projectDir: string,
  port: number,
  name: string,
  run: (client: AdminClient) => Promise<Result>,
): Promise<{ result: Result; revoked: boolean }> {
  const token = await mintApiKey(projectDir, {
    name,
    keyType: 'secret',
    scopes: ['write_all'],
    replace: true,
  })
  const client = createAdminClient({ baseUrl: `http://localhost:${port}`, secretKey: token })
  // Through the API, so it needs no rake round-trip.
  const revoke = async () => {
    try {
      const current = await client.apiKeys.current()
      await client.apiKeys.revoke(current.id)
      return true
    } catch {
      return false
    }
  }
  let result: Result
  try {
    result = await run(client)
  } catch (error) {
    await revoke()
    throw error
  }
  return { result, revoked: await revoke() }
}
