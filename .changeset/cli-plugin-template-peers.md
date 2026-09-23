---
"@spree/cli": patch
---

`spree plugin new` now scaffolds a dashboard plugin that installs against the current dashboard. Its `@spree/admin-sdk` and `@spree/dashboard-*` peer ranges come from the versions released alongside the CLI, instead of old `0.x` ranges no published package matched. The plugin package also gains a `build` script, so `pnpm build` at the plugin root no longer fails, and a `sideEffects` entry so bundlers never drop the import that registers the plugin. The generated README no longer describes an `engine/` directory the CLI does not create.

`spree build --production` builds from the project root again with the current starter Dockerfile, so a customized `apps/dashboard` is included in the image instead of being left out.
