import { cpSync } from 'node:fs'
import { defineConfig } from 'tsup'

const shared = {
  format: ['esm'] as const,
  target: 'node20' as const,
  platform: 'node' as const,
  noExternal: [/.*/],
  splitting: false,
  minify: true,
}

export default defineConfig([
  {
    ...shared,
    entry: ['src/index.ts'],
    banner: {
      js: [
        '#!/usr/bin/env node',
        'import { createRequire as __createRequire } from "node:module";',
        'const require = __createRequire(import.meta.url);',
      ].join('\n'),
    },
    // Copy the scaffolding templates into dist/ so the published tarball ships
    // them. `src/commands/plugin.ts` resolves the path relative to the running
    // file via `resolveTemplatePath()` — both `src/commands → ../../templates`
    // (dev) and `dist/index.js → ../templates` (published) work.
    async onSuccess() {
      cpSync('templates', 'dist/templates', { recursive: true })
    },
  },
  // The configurator engine as a library (`@spree/cli/config`): the dashboard
  // e2e setup and `spree init` import it without going through the binary.
  {
    ...shared,
    entry: { 'config/index': 'src/config/index.ts' },
    dts: { entry: { 'config/index': 'src/config/index.ts' } },
    banner: {
      js: [
        'import { createRequire as __createRequire } from "node:module";',
        'const require = __createRequire(import.meta.url);',
      ].join('\n'),
    },
  },
])
