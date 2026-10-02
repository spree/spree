// Deploys the store defaults (packages/config/templates) into the template
// database through the Admin API of a Rails server booted on it, then revokes
// the key it was given. Called by make-template.sh with the server's URL and
// a secret key minted for the run.
import { createAdminClient } from '@spree/admin-sdk'
import { provisionStore, renderReport, reportHasFailures } from '@spree/config'

const [baseUrl, secretKey] = process.argv.slice(2)
const client = createAdminClient({ baseUrl, secretKey, retry: false })
const report = await provisionStore(client)
await client.apiKeys.revoke((await client.apiKeys.current()).id)
if (reportHasFailures(report)) {
  console.error(renderReport(report))
  process.exit(1)
}
console.log(`✓ store defaults deployed (${report.results.length} records)`)
