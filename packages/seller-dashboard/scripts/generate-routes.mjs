// Regenerates the shell's committed routeTree.gen.ts.
//
// The shell is a library, not an app — it has no index.html, so a full
// `vite build` has no entry to resolve. Running Vite in dev-config mode gets
// the route generator (which runs on config resolution) without asking Vite
// to build anything.
import { createServer } from 'vite'

const server = await createServer({ configFile: './vite.config.ts', logLevel: 'error' })
await server.close()
