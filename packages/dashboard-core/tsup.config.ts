import { defineConfig } from 'tsup'

// Compile ONLY the Node-side Vite integration to JS. The rest of the package
// stays source-only (the host's Vite compiles it, and Tailwind scans the
// source) — but these entries are loaded by Node itself when a host's
// vite.config.ts imports them, and Node refuses to type-strip .ts files
// under node_modules (ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING). In the
// monorepo the workspace symlink hides this; registry installs hit it hard.
//
// bundle: false — transpile-only, 1:1 file mapping. Entry files import each
// other via explicit ./name.js specifiers, which stay valid in the emitted
// output.
export default defineConfig({
  entry: ['src/vite/index.ts', 'src/vite/discover.ts'],
  outDir: 'dist/vite',
  format: ['esm'],
  target: 'node20',
  bundle: false,
  splitting: false,
  clean: true,
})
