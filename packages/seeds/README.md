# @spree/seeds

The Spree seeds engine. It reads a `spree.seeds.yml`, plans the changes a live store needs to match it, and applies them through the Admin API, matching records on natural keys (code, slug, name, SKU) rather than ids. It also ships the defaults every new store starts with.

Most people use it through the CLI: `spree seed --dry-run`, `spree seed`, `spree seed introspect`. See the [seeds docs](https://spreecommerce.org/docs/developer/cli/seeds).

```ts
import { createAdminClient } from '@spree/admin-sdk'
import { deploySeeds, renderReport, reportHasFailures } from '@spree/seeds'
import { loadSeeds } from '@spree/seeds/node'

const { config } = loadSeeds('spree.seeds.yml')
const client = createAdminClient({ baseUrl, secretKey })
const report = await deploySeeds(config, client)
if (reportHasFailures(report)) throw new Error(renderReport(report))
```

The main entry runs in the browser; `@spree/seeds/node` adds reading files from disk.
