import { defineConfig } from 'tsup'

// `index` is browser-safe (the dashboard's setup screen runs it); `node`
// adds what needs the file system.
export default defineConfig({
  entry: { index: 'src/index.ts', node: 'src/node.ts' },
  format: ['esm'],
  dts: true,
  splitting: true,
  sourcemap: true,
  treeshake: true,
  external: ['@spree/admin-sdk'],
})
