import { defineConfig } from 'tsup'
import { spreePackagesRange } from './scripts/spree-packages-range.mjs'

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm'],
  target: 'node20',
  platform: 'node',
  noExternal: [/.*/],
  splitting: false,
  define: {
    __SPREE_PACKAGES_RANGE__: JSON.stringify(spreePackagesRange()),
  },
  clean: true,
  minify: true,
  banner: {
    js: [
      '#!/usr/bin/env node',
      'import { createRequire as __createRequire } from "node:module";',
      'const require = __createRequire(import.meta.url);',
    ].join('\n'),
  },
})
