import { defineConfig } from 'tsup'

// `index` is browser-safe (the dashboard's setup screen runs it); `node`
// adds what needs the file system. `sample-data` is its own entry, so the
// demo catalog's CSVs are only loaded by whoever runs it.
export default defineConfig({
  entry: { index: 'src/index.ts', node: 'src/node.ts', 'sample-data': 'src/sample-data.ts' },
  format: ['esm'],
  dts: true,
  splitting: true,
  sourcemap: true,
  treeshake: true,
  external: ['@spree/admin-sdk'],
})
