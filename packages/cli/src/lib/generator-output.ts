import pc from 'picocolors'

/** One line a generator logs about a file or setting, e.g. `create  app/models/brand.rb`. */
export interface GeneratorAction {
  verb: string
  target: string
}

export interface GeneratorResult {
  actions: GeneratorAction[]
  /** What the generator printed besides its action lines, such as its own next steps. */
  messages: string[]
}

// Rails generators log each action as a status right-aligned in 12 columns,
// then at least two spaces (more for a nested generator), then the target.
const STATUS_LINE = /^( *)([a-z_]+)( {2,})(\S.*)$/
const STATUS_WIDTH = 12

const VERBS: Record<string, string> = {
  create: 'created',
  insert: 'changed',
  inject: 'changed',
  append: 'changed',
  prepend: 'changed',
  gsub: 'changed',
  force: 'changed',
  route: 'changed',
  environment: 'changed',
  initializer: 'created',
  remove: 'removed',
  identical: 'unchanged',
  skip: 'skipped',
}

// Progress lines that say nothing about the result.
const HIDDEN_STATUSES = new Set(['invoke', 'revoke', 'exist', 'run', 'rake', 'generate'])

// ANSI escapes, in case a generator colours its output without a terminal.
// biome-ignore lint/suspicious/noControlCharactersInRegex: matching escape codes is the point
const ANSI = /\u001b\[[0-9;]*m/g

const BOOT_WARNING = /^\[[^\]]*WARNING\]/

/**
 * Parse a Rails generator's stdout into the actions it logged and the rest of
 * what it printed. Boot noise (lines starting with `[`, such as
 * `[Spree Events] …`) is dropped, except warnings.
 */
export function parseGeneratorOutput(stdout: string): GeneratorResult {
  const actions: GeneratorAction[] = []
  const messages: string[] = []
  let previousWasAction = false

  // A bare carriage return (a progress line redrawn in place) still ends a line.
  const text = stdout.replace(ANSI, '').replaceAll('\r\n', '\n').replaceAll('\r', '\n')
  for (const raw of text.split('\n')) {
    const match = STATUS_LINE.exec(raw)
    if (match && isStatusColumn(match[1], match[2])) {
      previousWasAction = true
      const status = match[2]
      if (HIDDEN_STATUSES.has(status)) continue
      actions.push({ verb: VERBS[status] ?? status, target: match[4].trim() })
      continue
    }

    // A multi-line action message continues under the target column.
    if (previousWasAction && /^ {14,}\S/.test(raw)) {
      const last = actions.at(-1)
      if (last) last.target += ` ${raw.trim()}`
      continue
    }
    previousWasAction = false

    // Drop boot noise such as `[Spree Events] …`, but keep warnings such as
    // `[Spree WARNING] Missing migrations.`
    if (raw.trimStart().startsWith('[') && !BOOT_WARNING.test(raw.trimStart())) continue
    const line = raw.trimEnd()
    if (line === '' && (messages.length === 0 || messages.at(-1) === '')) continue
    messages.push(line)
  }

  while (messages.at(-1) === '') messages.pop()
  return { actions, messages }
}

function isStatusColumn(indent: string, status: string): boolean {
  return (
    indent.length + status.length === STATUS_WIDTH ||
    (indent === '' && status.length > STATUS_WIDTH)
  )
}

/** Quote an argument for a POSIX shell unless it is plainly safe. */
export function shellQuote(arg: string): string {
  return /^[\w@%+=:,./-]+$/.test(arg) ? arg : `'${arg.replaceAll("'", `'\\''`)}'`
}

export interface NextStep {
  command: string
  reason?: string
}

/**
 * The commands to run after a generator, worked out from the files it touched:
 * a restart for anything loaded only at boot, `spree migrate` for a new
 * migration, and `spree test` for new specs. A step the generator already
 * names in its own output is left out.
 */
export function nextSteps(
  { actions, messages }: GeneratorResult,
  { pathPrefix = '' }: SummaryOptions = {},
): NextStep[] {
  const touched = actions
    .filter((action) => action.verb === 'created' || action.verb === 'changed')
    .map((action) => action.target.split(' ')[0])
  const steps: NextStep[] = []

  const bootFiles = touched.filter((path) =>
    /^config\/(initializers\/|environments\/|application\.rb)/.test(path),
  )
  if (bootFiles.length > 0) {
    steps.push({
      command: 'spree restart',
      reason: `${[...new Set(bootFiles)].map((file) => pathPrefix + file).join(', ')} ${bootFiles.length === 1 ? 'loads' : 'load'} only at boot`,
    })
  }

  if (touched.some((path) => path.startsWith('db/migrate/'))) {
    steps.push({ command: 'spree migrate' })
  }

  // The paths come from the container's output, and the command is meant to
  // be pasted into a shell, so anything unusual is quoted. `spree test` runs
  // in the container, so these stay relative to the app, without pathPrefix.
  const specs = touched.filter((path) => path.endsWith('_spec.rb')).map(shellQuote)
  if (specs.length > 0) steps.push({ command: `spree test ${specs.join(' ')}` })

  const printed = messages.join('\n')
  return steps.filter((step) => !printed.includes(step.command.split(' ').slice(0, 2).join(' ')))
}

export interface SummaryOptions {
  /**
   * Leads from where the command was run to the Rails app, e.g. `server/`, so
   * the files listed can be opened from there. Empty when run from the app.
   */
  pathPrefix?: string
}

// A target that names a file, such as `app/models/brand.rb`, `Gemfile` or a
// root dotfile like `.rspec`, as opposed to the code a `route` or
// `environment` action logs (`resources :brands`).
const FILE_TARGET = /^(?:[\w.-]+\/)+[\w.-]+$|^\.?[\w-]+\.[\w.]+$|^\.[\w-]+$|^Gemfile$/

function withPrefix(target: string, pathPrefix: string): string {
  return pathPrefix && FILE_TARGET.test(target.split(' ')[0]) ? pathPrefix + target : target
}

/** The short report `spree generate` prints in place of the generator's own output. */
export function formatGeneratorSummary(
  generator: string,
  result: GeneratorResult,
  options: SummaryOptions = {},
): string {
  const pathPrefix = options.pathPrefix ?? ''
  const lines: string[] = []
  const width = Math.max(0, ...result.actions.map((action) => action.verb.length)) + 2

  if (result.actions.length === 0) {
    lines.push(`${generator} finished without creating or changing any files.`)
  } else {
    lines.push(`${generator} finished:`)
    for (const { verb, target } of result.actions) {
      lines.push(`  ${colorVerb(verb, verb.padEnd(width))}${withPrefix(target, pathPrefix)}`)
    }
  }

  if (result.messages.length > 0) lines.push('', ...result.messages)

  const steps = nextSteps(result, { pathPrefix })
  if (steps.length > 0) {
    lines.push('', 'Next:')
    for (const { command, reason } of steps) {
      lines.push(`  ${pc.bold(command)}${reason ? pc.dim(`  # ${reason}`) : ''}`)
    }
  }

  return lines.join('\n')
}

function colorVerb(verb: string, text: string): string {
  if (verb === 'created' || verb === 'changed') return pc.green(text)
  if (verb === 'unchanged') return pc.dim(text)
  if (verb === 'removed') return text
  return pc.yellow(text)
}

/**
 * Collects a generator's output as it streams: the full transcript, for a
 * failure or `--verbose`, and stdout for the summary. A line still without a
 * newline after the generator goes quiet may be a prompt waiting for an answer
 * (`Overwrite app/models/brand.rb? [Ynaqdhm]`); `takePrompt` hands over the
 * part not yet shown. Showing it doesn't take it from the summary: when the
 * line ends, a status line split across chunks is parsed whole, and a prompt
 * shown earlier is dropped so the generator's next line parses on its own
 * (the answer is echoed by the terminal, not the generator).
 */
export class GeneratorOutput {
  private chunks: { text: string; stream: 'stdout' | 'stderr' }[] = []
  private stdout = ''
  private partial = ''
  private shown = 0

  write(text: string, stream: 'stdout' | 'stderr'): void {
    this.chunks.push({ text, stream })
    if (stream === 'stderr') return

    const lines = (this.partial + text).split('\n')
    this.partial = lines.pop() ?? ''
    if (lines.length === 0) return

    if (this.shown > 0 && !STATUS_LINE.test(lines[0])) lines[0] = lines[0].slice(this.shown)
    this.shown = 0
    this.stdout += `${lines.join('\n')}\n`
  }

  /** Whether part of the current line is waiting and could be a prompt. */
  hasPartialLine(): boolean {
    return this.partial.length > this.shown && !STATUS_LINE.test(this.partial)
  }

  takePrompt(): string {
    const prompt = this.partial.slice(this.shown)
    this.shown = this.partial.length
    return prompt
  }

  result(): GeneratorResult {
    return parseGeneratorOutput(this.stdout + this.partial.slice(this.shown))
  }

  /** Write everything the generator printed, each part to the stream it came from. */
  replay(out: { stdout: NodeJS.WritableStream; stderr: NodeJS.WritableStream }): void {
    for (const { text, stream } of this.chunks) out[stream].write(text)
  }
}
