# @spree/config

The Spree configurator engine. It reads a `spree.config.yml`, plans the changes a live store needs to match it, and applies them through the Admin API, matching records on natural keys (code, slug, name, SKU) rather than ids. It also ships the defaults every new store starts with.

Most people use it through the CLI: `spree config diff`, `spree config deploy`, `spree config introspect`. See the [configurator docs](https://spreecommerce.org/docs/developer/cli/configurator).

```ts
import { createAdminClient } from '@spree/admin-sdk'
import { deployConfig, renderReport, reportHasFailures } from '@spree/config'
import { loadConfig } from '@spree/config/node'

const { config } = loadConfig('spree.config.yml')
const client = createAdminClient({ baseUrl, secretKey })
const report = await deployConfig(config, client)
if (reportHasFailures(report)) throw new Error(renderReport(report))
```

The main entry runs in the browser; `@spree/config/node` adds reading files from disk.
