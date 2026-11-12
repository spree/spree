// Turns an agent transcript into the benchmark metrics. Claude Code and the
// Cursor CLI write the same stream-json events; Codex `exec --json` is read
// best-effort (see parseCodex).

// Installed Spree gem source, read on the host or inside the container.
const GEM_SOURCE = [
  /\/gems\/spree[_-]/,
  /\bbundle\s+(show|info|open)\s+spree/,
  /\bgem\s+(contents|which|open|unpack)\s+spree/,
  /Gem\.loaded_specs\[\s*['"]spree/,
  /\$\(bundle show/,
]
// @spree/docs is what agents are meant to read; every other @spree package is source.
const PACKAGE_SOURCE = /node_modules\/@spree\/(?!docs\b)[\w-]+/
const DOCS = [/node_modules\/@spree\/docs\b/, /spreecommerce\.org\/docs/]
const DOCS_TOOL = /spree.*docs|docs.*spree/i

const REMOVED_HINT = /Spree (\d+\.\d+) removed (\S+?)\.(?=\s|$)/g
const DEPRECATION_EXCEPTION = /ActiveSupport::DeprecationException/g
const DEPRECATION_WARNING = /DEPRECATION WARNING|is deprecated and will be removed in Spree/g

// Spree 4 and 5 idioms that Spree 6 removed. Kept narrow: a false positive
// here sends a maintainer reading a transcript for nothing.
export const LEGACY_PATTERNS = [
  ['Spree::Adjustment', /\bSpree::Adjustment\b/],
  ['.adjustments', /\.(all_)?adjustments\b/],
  ['product.master', /\b(product|@product)\.master\b/],
  ['payment_state / shipment_state', /\b(payment|shipment)_state\b/],
  ['checkout state machine', /\b(checkout_flow|insert_checkout_step|remove_checkout_step)\b/],
  ['Spree::PermittedAttributes', /\bSpree::PermittedAttributes\b/],
  ['Spree::PermissionSets', /\bSpree::PermissionSets\b/],
  ['Spree.user_class', /\bSpree\.user_class\b/],
  ['Spree::Taxon / Taxonomy', /\bSpree::Taxon(omy)?\b/],
  ['Spree::ReturnAuthorization', /\bSpree::(ReturnAuthorization|CustomerReturn|Reimbursement)\b/],
  ['Spree::Metafield', /\bSpree::Metafield\b/],
  ['API v2', /\/api\/v2\//],
  ['spree_frontend / spree_backend', /\bspree_(frontend|backend)\b/],
  ['order.completed event', /['"]order\.completed['"]/],
]

// Commands the generated AGENTS.md tells agents never to run directly. Only at
// the start of a command, so `spree exec bin/rails …` (allowed) is not counted.
const DIRECT_COMMANDS =
  /(^|[;&|(]\s*)\s*(bin\/rails|bin\/rake|bundle\s+(exec|install|add)|rspec|docker[\s-]compose)\b/m

const EDIT_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit'])

export function parseJsonl(text) {
  const events = []
  for (const line of text.split('\n')) {
    if (!line.trim()) continue
    try {
      events.push(JSON.parse(line))
    } catch {
      // Agents occasionally print a non-JSON line (a warning) between events.
    }
  }
  return events
}

export function toolResultText(content) {
  if (typeof content === 'string') return content
  if (!Array.isArray(content)) return ''
  return content
    .map((part) => (part?.type === 'text' ? part.text : ''))
    .filter(Boolean)
    .join('\n')
}

// Normalises Claude and Cursor stream-json into calls, results and a summary.
export function parseStreamJson(events) {
  const messageIds = new Set()
  let assistantEvents = 0
  const calls = []
  const results = []
  let final = null

  for (const event of events) {
    if (event.type === 'assistant' && event.message) {
      assistantEvents += 1
      if (event.message.id) messageIds.add(event.message.id)
      for (const block of event.message.content ?? []) {
        if (block.type === 'tool_use') {
          calls.push({ id: block.id, name: block.name, input: block.input ?? {} })
        }
      }
    } else if (event.type === 'user' && event.message) {
      const content = Array.isArray(event.message.content) ? event.message.content : []
      for (const block of content) {
        if (block.type === 'tool_result') {
          results.push({
            toolUseId: block.tool_use_id,
            text: toolResultText(block.content),
            isError: block.is_error === true,
          })
        }
      }
    } else if (event.type === 'result') {
      final = event
    }
  }

  return {
    modelCalls: messageIds.size || assistantEvents,
    calls,
    results,
    summary: final && {
      isError: final.is_error === true || (final.subtype && final.subtype !== 'success'),
      durationMs: final.duration_ms ?? null,
      numTurns: final.num_turns ?? null,
      costUsd: final.total_cost_usd ?? null,
      usage: final.usage ?? null,
    },
  }
}

// Codex `exec --json`: item.completed events carry commands, file changes and
// messages; turn.completed carries token usage. Cost is not reported.
export function parseCodex(events) {
  const calls = []
  const results = []
  let modelCalls = 0
  let usage = null
  for (const event of events) {
    if (event.type === 'turn.completed') {
      modelCalls += 1
      usage = event.usage ?? usage
    }
    if (event.type !== 'item.completed' || !event.item) continue
    const { item } = event
    if (item.type === 'command_execution') {
      calls.push({ id: item.id, name: 'Bash', input: { command: item.command } })
      results.push({
        toolUseId: item.id,
        text: item.aggregated_output ?? '',
        isError: item.exit_code != null && item.exit_code !== 0,
      })
    } else if (item.type === 'file_change') {
      calls.push({ id: item.id, name: 'Edit', input: { changes: item.changes } })
    } else if (item.type === 'mcp_tool_call') {
      calls.push({ id: item.id, name: `mcp__${item.server}__${item.tool}`, input: item.arguments })
    }
  }
  return {
    modelCalls,
    calls,
    results,
    summary: { isError: false, durationMs: null, numTurns: modelCalls, costUsd: null, usage },
  }
}

// Every string in a tool input, so a path or command anywhere in it is seen.
function inputText(input) {
  if (input == null) return ''
  if (typeof input === 'string') return input
  if (Array.isArray(input)) return input.map(inputText).join('\n')
  if (typeof input === 'object') return Object.values(input).map(inputText).join('\n')
  return String(input)
}

function excerpt(text, index = 0, length = 200) {
  const start = Math.max(0, index - 60)
  return text
    .slice(start, start + length)
    .replace(/\s+/g, ' ')
    .trim()
}

function count(regex, text) {
  return (text.match(regex) ?? []).length
}

export function computeMetrics(parsed) {
  const { calls, results } = parsed
  const callsById = new Map(calls.map((call) => [call.id, call]))
  const byTool = {}
  const stumbles = []
  const removedApis = {}
  let gemSourceReads = 0
  let packageSourceReads = 0
  let docsLookups = 0
  let legacyCodeWritten = 0
  let directCommands = 0

  for (const call of calls) {
    byTool[call.name] = (byTool[call.name] ?? 0) + 1
    const text = inputText(call.input)

    if (GEM_SOURCE.some((pattern) => pattern.test(text))) {
      gemSourceReads += 1
      stumbles.push({ kind: 'gem_source_read', tool: call.name, excerpt: excerpt(text) })
    }
    if (PACKAGE_SOURCE.test(text) && !EDIT_TOOLS.has(call.name)) packageSourceReads += 1
    if (DOCS.some((pattern) => pattern.test(text)) || DOCS_TOOL.test(call.name)) docsLookups += 1

    if (EDIT_TOOLS.has(call.name)) {
      for (const [label, pattern] of LEGACY_PATTERNS) {
        const match = pattern.exec(text)
        if (!match) continue
        legacyCodeWritten += 1
        stumbles.push({
          kind: 'legacy_code_written',
          api: label,
          excerpt: excerpt(text, match.index),
        })
      }
    }

    if (call.name === 'Bash' && DIRECT_COMMANDS.test(call.input?.command ?? '')) {
      directCommands += 1
      stumbles.push({ kind: 'direct_command', excerpt: excerpt(call.input.command) })
    }
  }

  let toolOutputChars = 0
  let toolErrors = 0
  let deprecationFailures = 0
  let deprecationWarnings = 0
  for (const result of results) {
    toolOutputChars += result.text.length
    if (result.isError) toolErrors += 1

    for (const match of result.text.matchAll(REMOVED_HINT)) {
      const name = match[2]
      removedApis[name] = (removedApis[name] ?? 0) + 1
      const call = callsById.get(result.toolUseId)
      stumbles.push({
        kind: 'removed_api',
        api: name,
        tool: call?.name,
        excerpt: excerpt(result.text, match.index),
      })
    }

    const failures = count(DEPRECATION_EXCEPTION, result.text)
    if (failures > 0) {
      deprecationFailures += failures
      const index = result.text.search(DEPRECATION_EXCEPTION)
      stumbles.push({ kind: 'deprecation_failure', excerpt: excerpt(result.text, index) })
    }
    deprecationWarnings += count(DEPRECATION_WARNING, result.text)
  }

  return {
    modelCalls: parsed.modelCalls,
    toolCalls: calls.length,
    toolCallsByName: byTool,
    toolOutputChars,
    toolErrors,
    gemSourceReads,
    packageSourceReads,
    docsLookups,
    removedApiUses: Object.values(removedApis).reduce((sum, n) => sum + n, 0),
    removedApis,
    legacyCodeWritten,
    deprecationFailures,
    deprecationWarnings,
    directCommands,
    agentError: parsed.summary?.isError ?? true,
    durationMs: parsed.summary?.durationMs ?? null,
    numTurns: parsed.summary?.numTurns ?? null,
    costUsd: parsed.summary?.costUsd ?? null,
    usage: parsed.summary?.usage ?? null,
    stumbles,
  }
}

// A run is clean when the check passed and nothing in the transcript shows the
// agent tripping over Spree on the way.
export function isClean(metrics, acceptancePassed) {
  return (
    acceptancePassed === true &&
    !metrics.agentError &&
    metrics.removedApiUses === 0 &&
    metrics.deprecationFailures === 0 &&
    metrics.gemSourceReads === 0
  )
}

export function scoreTranscript(text, { format = 'stream-json' } = {}) {
  const events = parseJsonl(text)
  const parsed = format === 'codex' ? parseCodex(events) : parseStreamJson(events)
  return computeMetrics(parsed)
}
