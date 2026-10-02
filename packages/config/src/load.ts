import { LineCounter, parseDocument } from 'yaml'
import type { ZodError } from 'zod'
import { ConfigError } from './errors.js'
import { configSchema, type SpreeConfig } from './schema.js'

// `$${NAME}` is the escape for a literal `${NAME}`.
const PLACEHOLDER = /\$(\$?)\{([A-Za-z_][A-Za-z0-9_]*)\}/g
const WHOLE_PLACEHOLDER = /^\$\{[A-Za-z_][A-Za-z0-9_]*\}$/

/** A validation problem with the file, one per offending value. */
export interface ConfigIssue {
  path: string
  line?: number
  message: string
}

export class ConfigValidationError extends Error {
  constructor(readonly issues: ConfigIssue[]) {
    super(
      issues
        .map(
          (issue) => `${issue.path}${issue.line ? ` (line ${issue.line})` : ''}: ${issue.message}`,
        )
        .join('\n'),
    )
    this.name = 'ConfigValidationError'
  }
}

export interface LoadedConfig {
  config: SpreeConfig
  /** Sections present in the file, in file order. */
  sections: string[]
}

/** `products[2].variants[0].sku` from a zod path. */
export function formatPath(segments: (string | number | symbol)[]): string {
  return segments.reduce<string>((path, segment) => {
    if (typeof segment === 'number') return `${path}[${segment}]`
    return path ? `${path}.${String(segment)}` : String(segment)
  }, '')
}

/**
 * Replaces `${ENV_VAR}` in every string with the variable's value, so a
 * committed file can carry a customer password or a provider key without
 * holding it. A missing variable is a file error, reported with its path.
 * Paths whose whole value was one placeholder are collected in `whole`, so
 * a number or a flag read from the environment can be typed afterwards.
 */
export function substituteEnv(
  value: unknown,
  env: NodeJS.ProcessEnv,
  path: (string | number)[] = [],
  whole?: Set<string>,
): unknown {
  if (typeof value === 'string') {
    if (WHOLE_PLACEHOLDER.test(value)) whole?.add(formatPath(path))
    return value.replace(PLACEHOLDER, (match, escaped: string, name: string) => {
      if (escaped) return match.slice(1)
      const resolved = env[name]
      if (resolved === undefined) {
        throw new ConfigError(`environment variable ${name} is not set`, formatPath(path))
      }
      return resolved
    })
  }
  if (Array.isArray(value))
    return value.map((item, index) => substituteEnv(item, env, [...path, index], whole))
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        key,
        substituteEnv(item, env, [...path, key], whole),
      ]),
    )
  }
  return value
}

/**
 * An environment variable is always text, so `stock: ${STOCK}` arrives as
 * `"5"`. Where the schema wanted a number or a flag at a path that was
 * nothing but a placeholder, the text is converted and the file checked again.
 */
function typePlaceholders(value: unknown, error: ZodError, whole: Set<string>): unknown | null {
  const copy = structuredClone(value)
  let changed = false
  for (const issue of error.issues) {
    if (issue.code !== 'invalid_type' || !['number', 'boolean'].includes(issue.expected)) continue
    const path = issue.path.filter(
      (segment): segment is string | number => typeof segment !== 'symbol',
    )
    if (!path.length || !whole.has(formatPath(path))) continue
    const parent = path
      .slice(0, -1)
      .reduce<Record<string | number, unknown>>(
        (node, segment) => node[segment] as Record<string | number, unknown>,
        copy as Record<string | number, unknown>,
      )
    const text = String(parent[path[path.length - 1]]).trim()
    const typed =
      issue.expected === 'number'
        ? text !== '' && Number.isFinite(Number(text))
          ? Number(text)
          : undefined
        : text === 'true' || text === 'false'
          ? text === 'true'
          : undefined
    if (typed === undefined) continue
    parent[path[path.length - 1]] = typed
    changed = true
  }
  return changed ? copy : null
}

function issuesFrom(error: ZodError, lineOf: (path: (string | number)[]) => number | undefined) {
  return error.issues.map((issue) => {
    const path = issue.path.filter(
      (segment): segment is string | number => typeof segment !== 'symbol',
    )
    return { path: formatPath(path) || '(root)', line: lineOf(path), message: issue.message }
  })
}

/**
 * Parses and validates YAML (or JSON — YAML is its superset) into a typed
 * config. Every problem is reported with its path and line before any
 * network call happens.
 */
export function parseConfig(source: string, env: NodeJS.ProcessEnv = process.env): LoadedConfig {
  const lineCounter = new LineCounter()
  const document = parseDocument(source, { lineCounter })
  if (document.errors.length > 0) {
    throw new ConfigValidationError(
      document.errors.map((error) => ({
        path: '(yaml)',
        line: error.linePos?.[0]?.line,
        message: error.message,
      })),
    )
  }
  const lineOf = (path: (string | number)[]): number | undefined => {
    const node = document.getIn(path, true) as { range?: [number, number, number] } | undefined
    return node?.range ? lineCounter.linePos(node.range[0]).line : undefined
  }

  const raw = document.toJS() ?? {}
  if (typeof raw !== 'object' || Array.isArray(raw)) {
    throw new ConfigValidationError([{ path: '(root)', message: 'the file must be a mapping' }])
  }

  let substituted: unknown
  const whole = new Set<string>()
  try {
    substituted = substituteEnv(raw, env, [], whole)
  } catch (error) {
    if (error instanceof ConfigError) {
      throw new ConfigValidationError([{ path: error.path, message: error.message }])
    }
    throw error
  }

  let result = configSchema.safeParse(substituted)
  if (!result.success && whole.size) {
    const typed = typePlaceholders(substituted, result.error, whole)
    if (typed) result = configSchema.safeParse(typed)
  }
  if (!result.success) throw new ConfigValidationError(issuesFrom(result.error, lineOf))

  const sections = Object.keys(raw as object).filter((key) => key !== 'version')
  return { config: result.data, sections }
}
