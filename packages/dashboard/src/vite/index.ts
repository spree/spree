import fs from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import tailwindcss from '@tailwindcss/vite'
import type { Plugin, PluginOption } from 'vite'

export interface SpreeDashboardPluginOptions {
  /**
   * Names of dashboard plugin packages installed in the host app. Each name
   * must be a resolvable npm package specifier — the same string you'd pass
   * to `import()`. The plugin resolves each one via Node module resolution
   * and tells Tailwind v4 to scan its source files for class usage.
   *
   * Example: `['@my-store/orders-plugin', '@my-store/wishlists-plugin']`.
   */
  plugins?: string[]
}

/**
 * Vite plugin that wires up the Spree dashboard: source-scanning for
 * Tailwind v4 plus `@tailwindcss/vite` itself, bundled together so the
 * ordering between them is guaranteed.
 *
 * Tailwind v4 doesn't scan `node_modules` by default and only accepts
 * filesystem paths in `@source` directives (not bare package specifiers).
 * The internal source plugin resolves every Spree dashboard package and
 * every host-named plugin through Node module resolution and injects
 * matching `@source` directives into the dashboard's CSS entry. Because
 * `@tailwindcss/vite` is wrapped alongside it here, the source plugin is
 * guaranteed to run first — the host doesn't have to think about plugin
 * ordering.
 *
 * Host apps should NOT add `@tailwindcss/vite` separately:
 *
 *     // host vite.config.ts
 *     import { spreeDashboardPlugin } from '@spree/dashboard/vite'
 *
 *     export default defineConfig({
 *       plugins: [
 *         spreeDashboardPlugin({
 *           plugins: ['@my-store/orders-plugin'],
 *         }),
 *         // … react(), TanStack Router, etc. — host owns these.
 *       ],
 *     })
 */
export function spreeDashboardPlugin(options: SpreeDashboardPluginOptions = {}): PluginOption[] {
  return [dashboardTailwindSourcePlugin(options), tailwindcss()]
}

function dashboardTailwindSourcePlugin(options: SpreeDashboardPluginOptions): Plugin {
  const pluginPackages = options.plugins ?? []

  // Resolution roots from this file's location. In dev, that's the workspace
  // copy of `@spree/dashboard`; in a published host app, it's
  // `node_modules/@spree/dashboard/...`. Either way, `node_modules/@spree/*`
  // packages are reachable from here.
  const fromHere = createRequire(import.meta.url)

  let resolvedSources: string[] = []

  return {
    name: 'spree:dashboard-tailwind-source',
    enforce: 'pre',

    configResolved() {
      const packagesToScan = ['@spree/dashboard-core', '@spree/dashboard-ui', ...pluginPackages]

      resolvedSources = packagesToScan
        .map((pkg) => resolvePackageSourceDir(pkg, fromHere))
        .filter((dir): dir is string => dir !== null)
    },

    transform(code, id) {
      if (!isDashboardStylesEntry(id)) return null

      const directives = resolvedSources.map((dir) => `@source '${dir}';`).join('\n')

      // Append after the user's CSS so any explicit `@source` they wrote
      // earlier wins on duplicates (Tailwind dedupes by resolved path anyway,
      // but ordering matters for human readability in dev tools).
      return {
        code: `${code}\n\n/* injected by @spree/dashboard/vite */\n${directives}\n`,
        map: null,
      }
    },
  }
}

/**
 * `@source` only applies to the file in which it's declared, so we need to
 * recognise the dashboard's stylesheet wherever it lives. We match by basename
 * `styles.css` inside any `@spree/dashboard` package. That covers the in-repo
 * dev shell (`packages/dashboard/src/styles.css`) and the published path
 * (`node_modules/@spree/dashboard/src/styles.css`).
 */
function isDashboardStylesEntry(id: string): boolean {
  const normalized = id.split('?')[0].replaceAll('\\', '/')
  return (
    /\/@spree\/dashboard\/src\/styles\.css$/.test(normalized) ||
    /\/packages\/dashboard\/src\/styles\.css$/.test(normalized)
  )
}

/**
 * Resolve `<package>/src` on disk. Resolves the package's main entry point
 * (defined by its `exports` map or `main` field) and walks upwards looking
 * for `package.json` to find the package root. Avoids requiring `<pkg>/package.json`
 * to be in the package's `exports` map — many packages, including ours,
 * don't list it there.
 */
function resolvePackageSourceDir(pkg: string, require: NodeJS.Require): string | null {
  try {
    const entryPath = require.resolve(pkg)
    const entryFile = entryPath.startsWith('file:') ? fileURLToPath(entryPath) : entryPath
    const packageRoot = findPackageRoot(entryFile)
    if (!packageRoot) return null
    return path.join(packageRoot, 'src')
  } catch {
    console.warn(
      `[@spree/dashboard/vite] Could not resolve '${pkg}'. ` +
        `Tailwind classes from this package won't be generated. ` +
        `Make sure the package is installed.`,
    )
    return null
  }
}

/**
 * Walk up from a file path until we find the directory containing
 * `package.json`. That directory is the package root.
 */
function findPackageRoot(fromFile: string): string | null {
  let current = path.dirname(fromFile)
  const { root } = path.parse(current)
  while (current !== root) {
    if (fs.existsSync(path.join(current, 'package.json'))) return current
    current = path.dirname(current)
  }
  return null
}
