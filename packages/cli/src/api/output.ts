import { SpreeError } from '@spree/admin-sdk'
import { printTable } from 'console-table-printer'
import pc from 'picocolors'
import { CredentialError } from '../config.js'

export type OutputFormat = 'json' | 'table'

/**
 * Prints an API result. JSON is the default; `--format table` renders
 * collections for humans.
 *
 * JSON adapts to the destination: a terminal gets indented, syntax-colored
 * output; a pipe or file gets compact, uncolored JSON so it stays fast and
 * `jq`-clean (color codes would corrupt it).
 */
export function printResult(result: unknown, format: OutputFormat = 'json'): void {
  if (result === undefined || result === null) return

  if (format === 'table') {
    const rows = collectionRows(result)
    if (rows) {
      printTable(rows.map(flattenScalars))
      return
    }
    const record = flattenScalars(result as Record<string, unknown>)
    printTable(Object.entries(record).map(([field, value]) => ({ field, value })))
    return
  }

  if (process.stdout.isTTY) {
    process.stdout.write(`${colorizeJson(JSON.stringify(result, null, 2))}\n`)
  } else {
    process.stdout.write(`${JSON.stringify(result)}\n`)
  }
}

// Token regex for already-formatted JSON: strings (object keys and values),
// literals, and numbers. Keys are strings immediately followed by a colon.
const JSON_TOKEN =
  /("(?:\\.|[^"\\])*"(\s*:)?)|\b(true|false|null)\b|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/g

/** Syntax-highlights pretty-printed JSON for the terminal (TTY only). Exported for tests. */
export function colorizeJson(json: string): string {
  return json.replace(JSON_TOKEN, (match, str, colon, literal, num) => {
    if (str !== undefined) {
      // A trailing colon marks an object key; color the key but leave the
      // colon uncolored.
      return colon ? pc.cyan(str.slice(0, -colon.length)) + colon : pc.green(str)
    }
    if (literal !== undefined) return pc.yellow(literal)
    if (num !== undefined) return pc.yellow(num)
    return match
  })
}

function collectionRows(result: unknown): Record<string, unknown>[] | null {
  if (Array.isArray(result)) return result as Record<string, unknown>[]
  if (result && typeof result === 'object' && Array.isArray((result as { data?: unknown }).data)) {
    return (result as { data: Record<string, unknown>[] }).data
  }
  return null
}

/** Keeps scalar fields; collapses nested objects/arrays so tables stay readable. */
function flattenScalars(row: Record<string, unknown>): Record<string, unknown> {
  const flat: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(row)) {
    if (value === null || ['string', 'number', 'boolean'].includes(typeof value)) {
      flat[key] = value
    } else if (Array.isArray(value)) {
      flat[key] = `[${value.length}]`
    } else {
      flat[key] = '{…}'
    }
  }
  return flat
}

/**
 * Maps failures to the documented exit codes: 1 for API errors (the
 * Stripe-style error envelope goes to stderr), 2 for usage/configuration
 * problems. Scope denials get the remediation hint — that text is what
 * agents read to self-correct.
 */
export function handleApiError(error: unknown, context: { baseUrl?: string } = {}): never {
  if (error instanceof SpreeError) {
    const details = error.details ? `\n${JSON.stringify({ details: error.details }, null, 2)}` : ''
    process.stderr.write(`${pc.red(`${error.code}:`)} ${error.message}${details}\n`)

    const requiredScope = (error.details as Record<string, unknown> | undefined)?.required_scope
    if (typeof requiredScope === 'string') {
      // Complete the agent self-correction loop: mint the key AND wire it in.
      process.stderr.write(
        `${pc.dim(`Hint: this key lacks \`${requiredScope}\`. Create one that has it and use it:`)}\n` +
          `${pc.dim(`  spree api-key create --type secret --scopes ${requiredScope}`)}\n` +
          `${pc.dim('  then pass it via --api-key <sk_...> or export SPREE_API_KEY=<sk_...>')}\n`,
      )
    }
    process.exit(1)
  }

  if (error instanceof CredentialError) {
    process.stderr.write(`${pc.red('error:')} ${error.message}\n`)
    process.exit(2)
  }

  // A fetch TypeError ("fetch failed") hides the real cause (ECONNREFUSED,
  // DNS failure, TLS) in error.cause — surface it with the target URL.
  if (error instanceof TypeError && /fetch failed/i.test(error.message)) {
    const cause = (error as { cause?: unknown }).cause
    const causeMessage = cause instanceof Error ? cause.message : cause ? String(cause) : ''
    const target = context.baseUrl ? ` (${context.baseUrl})` : ''
    process.stderr.write(
      `${pc.red('error:')} could not reach the server${target}${causeMessage ? `: ${causeMessage}` : ''}\n`,
    )
    process.stderr.write(
      `${pc.dim('Hint: check the URL, or run `spree api status` to diagnose reachability and credentials.')}\n`,
    )
    process.exit(2)
  }

  const message = error instanceof Error ? error.message : String(error)
  process.stderr.write(`${pc.red('error:')} ${message}\n`)
  process.exit(2)
}
