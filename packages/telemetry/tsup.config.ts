import { defineConfig } from 'tsup'

// Bundled into @spree/cli and create-spree-app at their build, so neither
// published package depends on this private one.
export default defineConfig({
  entry: { index: 'src/index.ts' },
  format: ['esm'],
  dts: true,
  target: 'node20',
  platform: 'node',
  splitting: false,
  clean: true,
})
