import { createRequire } from 'node:module'

// Resolve the CLI version from the package's own package.json at runtime rather
// than hardcoding it, so `spree --version` always reports the installed release.
// `../package.json` resolves the same whether this runs as the bundled
// `dist/index.js` or as `src/` source (tests), and npm always ships
// package.json in the published tarball.
const requirePackage = createRequire(import.meta.url)

export const VERSION: string = (requirePackage('../package.json') as { version: string }).version
