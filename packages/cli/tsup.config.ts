import { cpSync } from 'node:fs'
import { defineConfig } from 'tsup'

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm'],
  target: 'node20',
  platform: 'node',
  noExternal: [/.*/],
  splitting: false,
  clean: true,
  minify: true,
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
})
