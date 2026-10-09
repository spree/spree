import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import * as p from '@clack/prompts'
import { type FilterSpec, renderAppFilterTypes } from '@spree/sdk-core'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { rakeTask } from '../docker.js'

const APIS = ['store', 'admin', 'seller'] as const
type Api = (typeof APIS)[number]

interface TypesOptions {
  api: Api
  out: string
  from?: string
}

/**
 * The SDKs type list filters from Spree's own allowlists, so a filter an app
 * adds is a type error until declared. This writes that declaration from the
 * app's live filter tables, so it lists exactly what the app's API accepts.
 */
export function registerFiltersCommand(program: Command): void {
  const filters = program.command('filters').description("Work with your app's list filters")

  filters
    .command('types')
    .description("Generate TypeScript declarations for your app's own list filters and sort fields")
    .option('--api <api>', `which SDK to declare them for (${APIS.join(', ')})`, 'store')
    .option('--out <file>', 'where to write the declarations', 'src/types/spree-filters.d.ts')
    .option(
      '--from <file>',
      'read the filter tables from a file written by `bin/rails spree:api:filter_tables` instead of the running app',
    )
    .action(async (options: TypesOptions) => {
      if (!APIS.includes(options.api)) {
        p.log.error(`Unknown API "${options.api}". Use one of: ${APIS.join(', ')}.`)
        process.exitCode = 1
        return
      }

      const tables = options.from
        ? readFileSync(resolve(options.from), 'utf8')
        : await rakeTask('spree:api:filter_tables', detectProject().projectDir)
      const spec = parseFilterTables(tables)[options.api]

      const out = resolve(options.out)
      mkdirSync(dirname(out), { recursive: true })
      writeFileSync(out, renderAppFilterTypes(spec, options.api))
      p.log.success(`Wrote ${options.out}. Run this again after you change a filter.`)
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
