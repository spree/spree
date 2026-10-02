// Deploys the store defaults (packages/config/templates) into the template
// database through the Admin API of a Rails server booted on it. Called by
// make-template.sh with the server's URL and a secret key minted for the run.
import { createAdminClient } from '@spree/admin-sdk'
import { provisionStore, renderReport, reportHasFailures } from '@spree/config'

const [baseUrl, secretKey] = process.argv.slice(2)
const report = await provisionStore(createAdminClient({ baseUrl, secretKey, retry: false }))
if (reportHasFailures(report)) {
  console.error(renderReport(report))
  process.exit(1)
}
console.log(`✓ store defaults deployed (${report.results.length} records)`)
