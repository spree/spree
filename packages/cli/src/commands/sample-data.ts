import * as p from '@clack/prompts'
import { sampleData } from '@spree/config/sample-data'
import type { Command } from 'commander'
import { type CredentialFlags, clientFor, withCredentialFlags } from '../api/client.js'
import { handleApiError } from '../api/output.js'
import { withTemporaryKey } from '../api/temporary-key.js'
import { detectProject } from '../context.js'
import { loadSampleData } from '../sample-data.js'

const KEY_NAME = 'spree sample-data'

/** The project in the working directory, unless the flags point somewhere else. */
function localProject(flags: CredentialFlags) {
  if (flags.baseUrl || flags.apiKey || flags.profile) return null
  try {
    return detectProject()
  } catch {
    return null
  }
}

export function registerSampleDataCommand(program: Command): void {
  withCredentialFlags(
    program
      .command('sample-data')
      .description('Load the demo catalog, customers and wholesale setup through the Admin API'),
  ).action(async (flags: CredentialFlags) => {
    const s = p.spinner()
    const run = (client: Parameters<typeof loadSampleData>[0]) =>
      loadSampleData(client, sampleData(), (message) => s.message(message))
    let baseUrl: string | undefined
    try {
      s.start('Loading sample data...')
      const project = localProject(flags)
      if (project) {
        // The project's own key is read-only by design, and an import needs
        // an owner: a key minted now belongs to one of the store's admins.
        const { revoked } = await withTemporaryKey(project.projectDir, project.port, KEY_NAME, run)
        if (!revoked) {
          p.log.warn(
            `Could not revoke the key minted for this run; revoke "${KEY_NAME}" with \`spree api-key revoke\`.`,
          )
        }
      } else {
        const { client, credentials } = await clientFor(flags)
        baseUrl = credentials.baseUrl
        await run(client)
      }
      s.stop('Sample data loaded.')
    } catch (error) {
      s.stop('Could not load sample data.')
      handleApiError(error, baseUrl ? { baseUrl } : undefined)
    }
  })
}
