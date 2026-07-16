import { defineConfig } from 'tsup'

// Compile ONLY the Node-side Vite integration to JS — see the twin config in
// packages/dashboard-core for the full rationale (Node refuses to type-strip
// .ts under node_modules, and vite.config.ts imports resolve through Node).
//
// Output lands inside dist/ (which the app's `vite build` owns) in its own
// subdirectory, and this runs AFTER vite build in the package build script,
// so emptyOutDir can't erase it. bundle: false transpiles 1:1 — entry files
// import each other via explicit ./name.js specifiers, which stay valid in
// the emitted output, and bare imports (dashboard-core, TanStack) resolve
// through node_modules at runtime.
export default defineConfig({
  entry: ['src/vite/index.ts', 'src/vite/route-collisions.ts'],
  outDir: 'dist/vite-plugin',
  format: ['esm'],
  target: 'node20',
  bundle: false,
  splitting: false,
  clean: true,
})
