import fs from 'node:fs'
import { LineCounter, parseDocument } from 'yaml'
import type { ZodError } from 'zod'
import { ConfigError } from './errors.js'
import { configSchema, type SpreeConfig } from './schema.js'

const PLACEHOLDER = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g

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
 */
export function substituteEnv(
  value: unknown,
  env: NodeJS.ProcessEnv,
  path: (string | number)[] = [],
): unknown {
  if (typeof value === 'string') {
    return value.replace(PLACEHOLDER, (_match, name: string) => {
      const resolved = env[name]
      if (resolved === undefined) {
        throw new ConfigError(`environment variable ${name} is not set`, formatPath(path))
      }
      return resolved
    })
  }
  if (Array.isArray(value))
    return value.map((item, index) => substituteEnv(item, env, [...path, index]))
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, substituteEnv(item, env, [...path, key])]),
    )
  }
  return value
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
  try {
    substituted = substituteEnv(raw, env)
  } catch (error) {
    if (error instanceof ConfigError) {
      throw new ConfigValidationError([{ path: error.path, message: error.message }])
    }
    throw error
  }

  const result = configSchema.safeParse(substituted)
  if (!result.success) throw new ConfigValidationError(issuesFrom(result.error, lineOf))

  const sections = Object.keys(raw as object).filter((key) => key !== 'version')
  return { config: result.data, sections }
}

export function loadConfig(file: string, env: NodeJS.ProcessEnv = process.env): LoadedConfig {
  return parseConfig(fs.readFileSync(file, 'utf-8'), env)
}
