import { createAdminClient } from '@spree/admin-sdk'
import { type Command, Option } from 'commander'
import { printTable } from 'console-table-printer'
import pc from 'picocolors'
import { NO_BODY, readBody } from '../api/body.js'
import { handleApiError, type OutputFormat, printResult } from '../api/output.js'
import { buildParams, normalizePath } from '../api/params.js'
import {
  fetchCurrentKeyScopes,
  formatPingStatus,
  isPingFailure,
  pingCredentials,
} from '../api/ping.js'
import { getSchema, listEndpoints, loadBundledSpec } from '../api/spec.js'
import { type ResolvedCredentials, resolveCredentials } from '../config.js'

interface SharedFlags {
  profile?: string
  baseUrl?: string
  apiKey?: string
  storeId?: string
  format?: OutputFormat
}

interface VerbFlags extends SharedFlags {
  query: string[]
  sort?: string
  page?: string
  limit?: string
  expand?: string
  fields?: string
  data?: string
}

function collect(value: string, previous: string[]): string[] {
  return [...previous, value]
}

/** Credential flags shared by every subcommand that hits the API. */
function withCredentialFlags(command: Command): Command {
  return command
    .option('--profile <name>', 'use a saved profile (see `spree auth`)')
    .option('--base-url <url>', 'store URL (overrides profile/env/project)')
    .option(
      '--api-key <key>',
      'secret API key (prefer SPREE_API_KEY — flags leak into shell history)',
    )
    .option('--store-id <id>', 'X-Spree-Store-Id for hosts serving multiple stores')
}

/** The `--format json|table` option, shared by the verbs and `endpoints`. */
function formatOption(): Option {
  return new Option('--format <format>', 'output format').choices(['json', 'table']).default('json')
}

/** Credential flags plus `--format` for verbs that render a response. */
function withSharedFlags(command: Command): Command {
  return withCredentialFlags(command).addOption(formatOption())
}

async function clientFor(
  flags: SharedFlags,
): Promise<{ client: ReturnType<typeof createAdminClient>; credentials: ResolvedCredentials }> {
  const credentials = await resolveCredentials({
    baseUrl: flags.baseUrl,
    apiKey: flags.apiKey,
    profile: flags.profile,
  })
  const client = createAdminClient({
    baseUrl: credentials.baseUrl,
    secretKey: credentials.apiKey,
    ...(flags.storeId ? { storeId: flags.storeId } : {}),
  })
  return { client, credentials }
}

export function registerApiCommand(program: Command): void {
  const api = program
    .command('api')
    .description('Call the Admin API directly (generic get/post/patch/delete)')

  // Discovery pointers — shown on `spree api --help` and after an unknown
  // subcommand (the global showHelpAfterError prints help on usage errors).
  api.addHelpText(
    'after',
    [
      '',
      'Examples:',
      '  spree api get /products -q status_eq=active --limit 10',
      '  spree api post /products -d \'{"name":"Classic Tee","prices":[{"currency":"USD","amount":"29.99"}]}\'',
      '  spree api get /orders/ord_x8k2J9aQ --expand items,payments',
      '',
      'Discover the surface (offline, no server needed):',
      '  spree api endpoints --search <term>   # find endpoints + required scopes',
      '  spree api schema "POST /orders"       # request/response schema for one operation',
      '  spree completion zsh                  # tab-completion for paths, filters, scopes',
    ].join('\n'),
  )

  // --- Read verb -----------------------------------------------------------

  withSharedFlags(
    api
      .command('get <path>')
      .description('GET an Admin API path, e.g. `spree api get /products -q status_eq=active`')
      .option('-q, --query <expr>', 'Ransack predicate key=value (repeatable)', collect, [])
      .option('--sort <fields>', 'sort, e.g. -created_at')
      .option('--page <n>', 'page number')
      .option('--limit <n>', 'page size (max 100)')
      .option('--expand <relations>', 'expand relations, e.g. variants,variants.prices')
      .option('--fields <fields>', 'sparse fields, e.g. id,name'),
  ).action(async (path: string, flags: VerbFlags) => {
    let baseUrl: string | undefined
    try {
      // Build params before touching credentials so a typo'd -q fails fast
      // (exit 2) without triggering project key-minting.
      const params = buildParams(flags)
      const { client, credentials } = await clientFor(flags)
      baseUrl = credentials.baseUrl
      const result = await client.request('GET', normalizePath(path), { params })
      printResult(result, flags.format)
    } catch (error) {
      handleApiError(error, { baseUrl })
    }
  })

  // --- Write verbs ---------------------------------------------------------

  for (const method of ['post', 'patch', 'delete'] as const) {
    withSharedFlags(
      api
        .command(`${method} <path>`)
        .description(`${method.toUpperCase()} an Admin API path`)
        .option('-d, --data <json>', "request body: inline JSON, @file, or '-' for stdin"),
    ).action(async (path: string, flags: VerbFlags) => {
      let baseUrl: string | undefined
      try {
        // Read+parse the body before resolving credentials, so invalid JSON or
        // a missing file fails fast without minting a project key.
        const body = await readBody(flags.data)
        const { client, credentials } = await clientFor(flags)
        baseUrl = credentials.baseUrl
        const result = await client.request(method.toUpperCase(), normalizePath(path), {
          ...(body === NO_BODY ? {} : { body }),
        })
        printResult(result, flags.format)
      } catch (error) {
        handleApiError(error, { baseUrl })
      }
    })
  }

  // --- Schema introspection (bundled OpenAPI snapshot) ----------------------

  api
    .command('endpoints')
    .description('List Admin API endpoints with their required scopes')
    .option('--resource <name>', 'filter by first path segment, e.g. orders')
    .option('--search <term>', 'filter by method, path, or summary')
    .addOption(formatOption())
    .action((flags: { resource?: string; search?: string; format: OutputFormat }) => {
      const rows = listEndpoints(loadBundledSpec(), {
        resource: flags.resource,
        search: flags.search,
      })
      if (rows.length === 0) {
        process.stderr.write('No endpoints match.\n')
        process.exitCode = 1
        return
      }
      if (flags.format === 'table') {
        printTable(
          rows.map((row) => ({
            Method: row.method,
            Path: row.path,
            Scope: row.scope,
            Summary: row.summary,
          })),
        )
        return
      }
      printResult(rows, 'json')
    })

  api
    .command('schema <operation>')
    .description(
      'Show the request/response schema for an operation, e.g. `spree api schema "POST /products"`',
    )
    .action((operation: string) => {
      const matches = getSchema(loadBundledSpec(), operation)
      if (matches.length === 0) {
        process.stderr.write(
          `No operation matches "${operation}". Try \`spree api endpoints --search ${operation.split(/\s+/).pop()}\`.\n`,
        )
        process.exitCode = 1
        return
      }
      // A fully-qualified "METHOD /path" matches at most one operation → emit
      // the bare object; an ambiguous lookup always emits an array so the
      // shape is predictable for scripts.
      const fullyQualified = /\s/.test(operation.trim())
      printResult(fullyQualified && matches.length === 1 ? matches[0] : matches, 'json')
    })

  // --- Connection check ----------------------------------------------------

  withCredentialFlags(
    api
      .command('status')
      .description('Show resolved credentials, server reachability, and the bundled spec version'),
  ).action(async (flags: SharedFlags) => {
    try {
      const credentials = await resolveCredentials(
        { baseUrl: flags.baseUrl, apiKey: flags.apiKey, profile: flags.profile },
        { allowMint: false },
      )
      const ping = await pingCredentials(credentials.baseUrl, credentials.apiKey)
      const spec = loadBundledSpec()
      const serverLine = formatPingStatus(ping)

      const lines = [
        `${pc.bold('Base URL:')}     ${credentials.baseUrl}`,
        `${pc.bold('Credentials:')}  ${credentials.source}${credentials.profileName ? ` (${credentials.profileName})` : ''}, key ${credentials.tokenPrefix}${pc.dim('…')}`,
      ]
      // Prefer the key's live scopes from the server — they reflect any
      // server-side scope changes. The `scopes` cached in .spree/credentials.json
      // is only what was requested at mint time and can drift. Fall back to that
      // local snapshot (clearly labelled) when the server can't report scopes
      // (older server, JWT principal, or an unreachable host).
      const liveScopes =
        ping.status === 'unreachable' || ping.status === 'unauthorized'
          ? null
          : await fetchCurrentKeyScopes(credentials.baseUrl, credentials.apiKey)
      // A non-null result is authoritative — including an empty array, which
      // means the key genuinely has no scopes. Only fall back to the local
      // snapshot when the server couldn't report them at all (null).
      if (liveScopes !== null) {
        lines.push(
          `${pc.bold('Scopes:')}       ${liveScopes.length ? liveScopes.join(', ') : pc.dim('(none)')}`,
        )
      } else if (credentials.scopes?.length) {
        lines.push(
          `${pc.bold('Scopes:')}       ${credentials.scopes.join(', ')} ${pc.dim('(local snapshot from mint time — may be stale)')}`,
        )
      }
      lines.push(`${pc.bold('Server:')}       ${serverLine}`)
      lines.push(
        `${pc.bold('Bundled spec:')} ${spec.info?.version ?? 'unknown'} ${pc.dim('(spree api endpoints/schema reflect this snapshot, not the live server)')}`,
      )
      process.stdout.write(`${lines.join('\n')}\n`)

      if (isPingFailure(ping)) {
        process.exitCode = 1
      }
    } catch (error) {
      handleApiError(error, { baseUrl: flags.baseUrl })
    }
  })
}
