import type { Command } from 'commander'
// Import the tiny precomputed path list, NOT the full spec — completion fires
// on every Tab keypress and only needs the ~40 resource path segments.
import RESOURCE_PATHS from '../generated/resource-paths.json' with { type: 'json' }

/**
 * Shell completion, following the `gh`/`kubectl` architecture: `spree
 * completion <shell>` prints a static script that, on Tab, calls a hidden
 * `spree __complete <words...>` subcommand. The resolver reads the bundled
 * OpenAPI snapshot (offline — no server, no network), so it can suggest live
 * resource paths, verbs, Ransack predicates, and scopes.
 */

const SHELLS = ['bash', 'zsh', 'fish'] as const
type Shell = (typeof SHELLS)[number]

// Ransack predicate suffixes for `-q <attr>_<predicate>=…`. A fixed, well-known
// set (the matchers are not enumerated per-attribute in the spec), so we offer
// the common ones rather than every Ransack matcher.
const RANSACK_PREDICATES = [
  'eq',
  'not_eq',
  'cont',
  'not_cont',
  'start',
  'end',
  'in',
  'not_in',
  'gt',
  'gteq',
  'lt',
  'lteq',
  'null',
  'not_null',
  'present',
  'blank',
]

const API_VERBS = ['get', 'post', 'patch', 'delete', 'endpoints', 'schema', 'status']

// Keep in sync with `Spree::ApiKey::SCOPES` (spree/core/app/models/spree/api_key.rb).
// Not derived from the bundled spec: the spec only annotates per-endpoint
// scopes, so the aggregate scopes (read_all/write_all/read_dashboard) wouldn't
// appear. Hand-maintained, hence this pointer.
const SCOPES = [
  'read_all',
  'write_all',
  'read_orders',
  'write_orders',
  'read_products',
  'write_products',
  'read_promotions',
  'write_promotions',
  'read_customers',
  'write_customers',
  'read_payments',
  'write_payments',
  'read_fulfillments',
  'write_fulfillments',
  'read_refunds',
  'write_refunds',
  'read_gift_cards',
  'write_gift_cards',
  'read_store_credits',
  'write_store_credits',
  'read_stock',
  'write_stock',
  'read_categories',
  'write_categories',
  'read_settings',
  'write_settings',
  'read_webhooks',
  'write_webhooks',
  'read_api_keys',
  'write_api_keys',
  'read_dashboard',
]

/**
 * Resolves completion candidates for a partial command line. `words` is the
 * argv after `spree` (the last entry is the word being typed, possibly empty).
 */
export function completionCandidates(words: string[]): string[] {
  const [top, sub, ...rest] = words
  const current = words[words.length - 1] ?? ''
  const preceding = words[words.length - 2] ?? ''

  // `spree <TAB>` — top-level command names (plus the api verbs surfaced flat).
  if (words.length <= 1) {
    return filterByPrefix(['api', 'auth', ...TOP_LEVEL_HINT], current)
  }

  // Value position: gate predicate/scope suggestions on the immediately
  // preceding option so they don't appear in unrelated argument slots.
  // `-q <attr>_<TAB>` → append Ransack predicates to the typed attribute stem.
  if (
    (preceding === '-q' || preceding === '--query') &&
    current.includes('_') &&
    !current.includes('=')
  ) {
    const stem = current.slice(0, current.lastIndexOf('_') + 1)
    return RANSACK_PREDICATES.map((p) => `${stem}${p}=`)
  }
  // `--scopes <TAB>` → scope names (comma-joined values complete the last one).
  if (preceding === '--scopes') {
    const typed = current.includes(',') ? current.slice(current.lastIndexOf(',') + 1) : current
    const head = current.slice(0, current.length - typed.length)
    return filterByPrefix(SCOPES, typed).map((s) => head + s)
  }

  if (top === 'api') {
    // `spree api <TAB>` — verbs.
    if (words.length === 2) return filterByPrefix(API_VERBS, current)

    // `spree api get /pro<TAB>` — resource paths (only for path-taking verbs).
    if (['get', 'post', 'patch', 'delete', 'schema'].includes(sub) && rest.length <= 1) {
      return filterByPrefix(RESOURCE_PATHS, current)
    }
  }

  return []
}

// A few high-traffic top-level commands so `spree <TAB>` isn't empty; the full
// list comes from Commander's own help. Kept short on purpose.
const TOP_LEVEL_HINT = ['api-key', 'dev', 'console', 'migrate']

function filterByPrefix(candidates: string[], prefix: string): string[] {
  if (!prefix) return candidates
  return candidates.filter((c) => c.startsWith(prefix))
}

function completionScript(shell: Shell): string {
  if (shell === 'fish') {
    return `# spree fish completion — eval "$(spree completion fish)"
function __spree_complete
  set -l tokens (commandline -opc) (commandline -ct)
  spree __complete $tokens[2..-1]
end
complete -c spree -f -a '(__spree_complete)'
`
  }

  if (shell === 'zsh') {
    return `# spree zsh completion — eval "$(spree completion zsh)"
_spree() {
  local -a completions
  completions=(\${(f)"$(spree __complete \${words[2,$CURRENT]})"})
  compadd -- $completions
}
compdef _spree spree
`
  }

  // bash
  return `# spree bash completion — eval "$(spree completion bash)"
_spree() {
  local words=("\${COMP_WORDS[@]:1:$COMP_CWORD}")
  COMPREPLY=( $(spree __complete "\${words[@]}") )
}
complete -F _spree spree
`
}

export function registerCompletionCommand(program: Command): void {
  program
    .command('completion <shell>')
    .description('Output a shell completion script (bash, zsh, or fish)')
    .action((shell: string) => {
      if (!SHELLS.includes(shell as Shell)) {
        process.stderr.write(`Unsupported shell "${shell}". Choose one of: ${SHELLS.join(', ')}.\n`)
        process.exitCode = 2
        return
      }
      process.stdout.write(completionScript(shell as Shell))
    })

  // Hidden resolver the generated scripts call on Tab. Prints one candidate
  // per line; offline (reads the bundled spec only).
  program
    .command('__complete', { hidden: true })
    .allowUnknownOption()
    .argument('[words...]')
    .action((words: string[]) => {
      for (const candidate of completionCandidates(words ?? [])) {
        process.stdout.write(`${candidate}\n`)
      }
    })
}
