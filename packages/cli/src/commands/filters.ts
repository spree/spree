import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import * as p from '@clack/prompts'
import { type FilterSpec, renderAppFilterTypes } from '@spree/sdk-core'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { rakeTask } from '../docker.js'

const APIS = ['store', 'admin', 'seller'] as const
type Api = (typeof APIS)[number]

interface TypesOptions {
  api?: Api
  out?: string
  from?: string
}

/** The apps `create-spree-app` scaffolds under `apps/`, and the SDK each uses. */
export const APP_SDKS: { dir: string; api: Api }[] = [
  { dir: 'storefront', api: 'store' },
  { dir: 'dashboard', api: 'admin' },
  { dir: 'seller-dashboard', api: 'seller' },
]
const APP_TYPES_FILE = join('src', 'types', 'spree-filters.d.ts')
const DEFAULT_OUT = APP_TYPES_FILE

/**
 * The SDKs type list filters from Spree's own allowlists, so a filter an app
 * adds is a type error until declared. This writes that declaration from the
 * app's live filter tables, so it lists exactly what the app's API accepts.
 *
 * Without `--api` or `--out` it writes one file into each app under `apps/`,
 * for the SDK that app uses; with them, one file where asked.
 */
export function registerFiltersCommand(program: Command): void {
  const filters = program.command('filters').description("Work with your app's list filters")

  filters
    .command('types')
    .description("Generate TypeScript declarations for your app's own list filters and sort fields")
    .option(
      '--api <api>',
      `write one file, for this SDK (${APIS.join(', ')}), instead of one per app under apps/`,
    )
    .option('--out <file>', `where to write that one file (default: ${DEFAULT_OUT})`)
    .option(
      '--from <file>',
      'read the filter tables from a file written by `bin/rails spree:api:filter_tables` instead of the running app',
    )
    .action(async (options: TypesOptions) => {
      if (options.api && !APIS.includes(options.api)) {
        p.log.error(`Unknown API "${options.api}". Use one of: ${APIS.join(', ')}.`)
        process.exitCode = 1
        return
      }

      const single = options.api !== undefined || options.out !== undefined
      // With --from the app need not run in this CLI's Docker setup; the
      // current folder is then taken as the project root.
      const projectDir = single && options.from ? undefined : projectRoot(Boolean(options.from))
      const targets = single
        ? [{ api: options.api ?? 'store', out: resolve(options.out ?? DEFAULT_OUT) }]
        : APP_SDKS.filter(({ dir }) => existsSync(join(projectDir as string, 'apps', dir))).map(
            ({ dir, api }) => ({
              api,
              out: join(projectDir as string, 'apps', dir, APP_TYPES_FILE),
            }),
          )

      if (targets.length === 0) {
        p.log.error(
          'No apps found under apps/. Pass --api and --out to write the declarations somewhere else.',
        )
        process.exitCode = 1
        return
      }

      const tables = parseFilterTables(
        options.from
          ? readFileSync(resolve(options.from), 'utf8')
          : await rakeTask('spree:api:filter_tables', projectDir as string),
      )

      for (const { api, out } of targets) {
        mkdirSync(dirname(out), { recursive: true })
        writeFileSync(out, renderAppFilterTypes(tables[api], api))
        p.log.success(`Wrote ${projectDir ? relative(projectDir, out) : out} (${api} API)`)
      }
      p.log.info('Run this again after you change a filter.')
    })
}

/**
 * The task prints its JSON on one line; Rails may print boot messages around
 * it, in a file redirected from the task as much as in the CLI's own capture.
 */
export function parseFilterTables(output: string): Record<Api, FilterSpec> {
  const json = output.split('\n').find((line) => line.trimStart().startsWith('{'))
  if (!json)
    throw new Error(
      'No filter tables found. Run `bin/rails spree:api:filter_tables` to check its output.',
    )

  return JSON.parse(json) as Record<Api, FilterSpec>
}

function projectRoot(fromFile: boolean): string {
  try {
    return detectProject().projectDir
  } catch (error) {
    if (fromFile) return process.cwd()
    throw error
  }
}
