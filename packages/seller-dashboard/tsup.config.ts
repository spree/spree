import { defineConfig } from 'tsup'

// Compile ONLY the Node-side Vite integration to JS — Node refuses to
// type-strip .ts under node_modules, and vite.config.ts imports resolve
// through Node. bundle: false transpiles 1:1; bare imports (dashboard-core,
// TanStack) resolve through node_modules at runtime.
export default defineConfig({
  entry: ['src/vite/index.ts'],
  outDir: 'dist/vite-plugin',
  format: ['esm'],
  target: 'node20',
  bundle: false,
  splitting: false,
  clean: true,
})
