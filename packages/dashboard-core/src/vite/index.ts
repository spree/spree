import fs from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
// Self-referencing package import (not a relative path): this entry is loaded
// raw by Node when a host's vite.config.ts imports `@spree/dashboard-core/vite`,
// and Node's TS type-stripping can't resolve extensionless relative specifiers.
// The exports-map path resolves to the real file name everywhere.
import { discoverDashboardPlugins } from '@spree/dashboard-core/vite/discover'
import tailwindcss from '@tailwindcss/vite'
import type { Plugin, PluginOption } from 'vite'

export interface SpreeDashboardPluginOptions {
  /**
   * Path to the host app's CSS entry file (the one that does
   * `@import "@spree/dashboard-ui/styles.css"`). Resolved relative to the
   * host's project root. The plugin injects `@source` directives into this
   * file so Tailwind v4 scans every Spree dashboard package and every
   * dashboard plugin for class usage.
   *
   * Defaults to `./src/styles.css`, which fits the conventional Vite layout.
   */
  cssEntry?: string

  /**
   * Names of dashboard plugin packages installed in the host app. Each name
   * must be a resolvable npm package specifier — the same string you'd pass
   * to `import()`. The plugin resolves each one via Node module resolution
   * and tells Tailwind v4 to scan its source files for class usage.
   *
   * When omitted (the typical case), the plugin auto-discovers installed
   * dashboard plugins by walking the host's `package.json` dependencies and
   * picking up anything that declares
   * `"spree": { "dashboard": { "plugin": true } }`. Pass an explicit array
   * to opt out of auto-discovery — useful for whitelisting in tightly
   * controlled environments.
   *
   * Example: `['@my-store/orders-plugin', '@my-store/wishlists-plugin']`.
   */
  plugins?: string[]
}

/**
 * Vite plugin that wires up Tailwind v4 for a Spree dashboard.
 *
 * Combines two concerns:
 *
 *   1. Source-scanning: tells Tailwind to scan `@spree/dashboard-core`,
 *      `@spree/dashboard-ui`, and any host-named plugin packages, by
 *      injecting `@source` directives into the host's CSS entry. Tailwind v4
 *      doesn't scan `node_modules` by default and only accepts filesystem
 *      paths in `@source` directives (not bare package specifiers), so we
 *      resolve each package through Node module resolution to get an
 *      absolute path that works under any package layout (workspace
 *      symlinks, npm tarballs, pnpm's `.pnpm/` hoisting).
 *
 *   2. Tailwind itself: returns `@tailwindcss/vite` bundled alongside the
 *      source-injection plugin, in the right order. Hosts don't add
 *      `@tailwindcss/vite` separately.
 *
 * Usage from a host using the full `@spree/dashboard` app shell:
 *
 *     // host vite.config.ts
 *     import { spreeDashboardPlugin } from '@spree/dashboard-core/vite'
 *
 *     export default defineConfig({
 *       plugins: [
 *         spreeDashboardPlugin({
 *           plugins: ['@my-store/orders-plugin'],
 *         }),
 *         // … react(), TanStack Router, etc. — host owns these.
 *       ],
 *     })
 *
 * For a custom dashboard built on `@spree/dashboard-core` + `@spree/dashboard-ui`,
 * point `cssEntry` at the host's own CSS file:
 *
 *     spreeDashboardPlugin({
 *       cssEntry: './src/admin.css',
 *       plugins: ['@my-store/vendor-portal-plugin'],
 *     })
 */
export function spreeDashboardPlugin(options: SpreeDashboardPluginOptions = {}): PluginOption[] {
  return [dashboardTailwindSourcePlugin(options), tailwindcss()]
}

function dashboardTailwindSourcePlugin(options: SpreeDashboardPluginOptions): Plugin {
  const explicitPlugins = options.plugins
  const cssEntry = options.cssEntry ?? './src/styles.css'

  // Resolution roots from this file's location. Wherever
  // `@spree/dashboard-core` ends up on disk (workspace symlink, hoisted
  // npm install, pnpm `.pnpm/` directory), the sibling `@spree/*` packages
  // are reachable from here via Node module resolution.
  const fromHere = createRequire(import.meta.url)

  let resolvedSources: string[] = []
  let resolvedCssEntry = ''
  let pluginErrors: PluginError[] = []

  return {
    name: 'spree:dashboard-tailwind-source',
    enforce: 'pre',

    configResolved(config) {
      resolvedCssEntry = path.resolve(config.root, cssEntry).split(path.sep).join('/')

      // `plugins: []` is an explicit empty whitelist; only `plugins` omitted
      // triggers discovery. Discovery walks the host's package.json deps and
      // returns names that opt-in via the `spree.dashboard.plugin` marker.
      const pluginPackages =
        explicitPlugins ??
        discoverDashboardPlugins({
          root: config.root,
          onWarn: (msg) => console.warn(`[@spree/dashboard-core/vite] ${msg}`),
        })

      const packagesToScan = ['@spree/dashboard-core', '@spree/dashboard-ui', ...pluginPackages]

      pluginErrors = []
      resolvedSources = []
      for (const pkg of packagesToScan) {
        const dir = resolvePackageSourceDir(pkg, fromHere)
        if (dir) {
          resolvedSources.push(dir)
        } else {
          pluginErrors.push({ pkg, kind: 'unresolved' })
        }
      }
    },

    transform(code, id) {
      const normalized = id.split('?')[0].replaceAll('\\', '/')
      if (normalized !== resolvedCssEntry) return null

      const directives = resolvedSources.map((dir) => `@source '${dir}';`).join('\n')

      return {
        code: `${code}\n\n/* injected by @spree/dashboard-core/vite */\n${directives}\n`,
        map: null,
      }
    },

    configureServer(server) {
      // Surface unresolved plugins as a Vite error overlay in dev so the
      // failure mode is loud. Without this, a missing plugin silently emits
      // unstyled HTML when the host imports it. Sent once per client
      // connection rather than per HTTP request.
      if (pluginErrors.length === 0) return
      const message = formatPluginErrorOverlay(pluginErrors)
      server.ws.on('connection', () => {
        server.ws.send({
          type: 'error',
          err: {
            message,
            stack: '',
            plugin: 'spree:dashboard-tailwind-source',
          },
        })
      })
    },
  }
}

interface PluginError {
  pkg: string
  kind: 'unresolved'
}

function formatPluginErrorOverlay(errors: PluginError[]): string {
  const lines = [
    'Spree dashboard plugin(s) could not be resolved:',
    '',
    ...errors.map(({ pkg }) => `  - ${pkg}`),
    '',
    'For each one, check:',
    '  1. The package is installed (`pnpm add <package>`)',
    '  2. Its package.json declares the dashboard marker:',
    '       { "spree": { "dashboard": { "plugin": true } } }',
    '',
    'If you registered it explicitly via spreeDashboardPlugin({ plugins: [...] }),',
    'verify the name matches the installed package exactly.',
  ]
  return lines.join('\n')
}

/**
 * Resolve `<package>/src` on disk. Resolves the package's main entry point
 * (defined by its `exports` map or `main` field) and walks upwards looking
 * for `package.json` to find the package root. Avoids requiring
 * `<pkg>/package.json` to be in the package's `exports` map — many packages,
 * including ours, don't list it there.
 */
function resolvePackageSourceDir(pkg: string, require: NodeJS.Require): string | null {
  try {
    const entryPath = require.resolve(pkg)
    const entryFile = entryPath.startsWith('file:') ? fileURLToPath(entryPath) : entryPath
    const packageRoot = findPackageRoot(entryFile)
    if (!packageRoot) return null
    return path.join(packageRoot, 'src')
  } catch {
    return null
  }
}

function findPackageRoot(fromFile: string): string | null {
  let current = path.dirname(fromFile)
  const { root } = path.parse(current)
  while (current !== root) {
    if (fs.existsSync(path.join(current, 'package.json'))) return current
    current = path.dirname(current)
  }
  return null
}
