/**
 * Schema introspection over the bundled Admin API OpenAPI snapshot
 * (src/generated/admin-spec.json, regenerated per release by
 * scripts/bundle-spec.mjs). Powers `spree api endpoints` / `spree api schema`.
 */

// Bundled at build time by tsup (the package ships a single inlined file, so
// the snapshot becomes a module literal — there is no separate JSON file to
// read at runtime). `spree api get`/`post`/… reference loadBundledSpec() only
// indirectly, and a JS object literal costs nothing until used.
import adminSpecJson from '../generated/admin-spec.json' with { type: 'json' }
import { normalizePath } from './params.js'

export interface OpenApiOperation {
  summary?: string
  description?: string
  tags?: string[]
  parameters?: Array<Record<string, unknown>>
  requestBody?: Record<string, unknown>
  responses?: Record<string, unknown>
}

export interface AdminSpec {
  info?: { title?: string; version?: string }
  paths: Record<string, Record<string, OpenApiOperation>>
  components: { schemas: Record<string, unknown> }
}

export interface EndpointRow {
  method: string
  path: string
  scope: string
  summary: string
}

const HTTP_METHODS = new Set(['get', 'post', 'put', 'patch', 'delete'])

export function loadBundledSpec(): AdminSpec {
  return adminSpecJson as unknown as AdminSpec
}

/**
 * Extracts the `**Required scope:** ...` line rswag writes into operation
 * descriptions. Free-form notes (e.g. exports — gated by the exported
 * resource) come through verbatim.
 *
 * The same annotation is parsed at build time by
 * `scripts/generate-endpoints-doc.mjs` (a separate `.mjs` runtime, so the
 * logic can't be shared as an import); keep the two in sync if the rswag
 * `admin_scope` format changes.
 */
export function requiredScope(operation: OpenApiOperation): string {
  const match = operation.description?.match(
    /\*\*Required scope:\*\* (.+?) \(for API-key authentication\)\./,
  )
  if (!match) return '—'
  return match[1].replaceAll('`', '')
}

export function listEndpoints(
  spec: AdminSpec,
  filter: { resource?: string; search?: string } = {},
): EndpointRow[] {
  const rows: EndpointRow[] = []

  for (const [specPath, methods] of Object.entries(spec.paths)) {
    const shortPath = specPath.replace('/api/v3/admin', '') || '/'

    for (const [method, operation] of Object.entries(methods)) {
      if (!HTTP_METHODS.has(method)) continue

      if (filter.resource) {
        const segment = shortPath.split('/')[1] ?? ''
        if (segment !== filter.resource && !segment.startsWith(filter.resource)) continue
      }

      const summary = operation.summary ?? ''
      if (filter.search) {
        const haystack = `${method} ${shortPath} ${summary}`.toLowerCase()
        if (!haystack.includes(filter.search.toLowerCase())) continue
      }

      rows.push({
        method: method.toUpperCase(),
        path: shortPath,
        scope: requiredScope(operation),
        summary,
      })
    }
  }

  return rows
}

export interface SchemaResult {
  method: string
  path: string
  summary?: string
  description?: string
  parameters?: unknown
  requestBody?: unknown
  responses?: unknown
}

/**
 * Returns the full operation schema for `METHOD /path` (method optional when
 * the path has exactly one operation), with `$ref`s resolved inline so the
 * output is self-contained. Matching tolerates the `/api/v3/admin` prefix and
 * concrete IDs in place of `{id}` placeholders.
 */
export function getSchema(spec: AdminSpec, target: string): SchemaResult[] {
  const parts = target.trim().split(/\s+/)
  const method = parts.length > 1 ? parts[0].toLowerCase() : undefined
  const rawPath = parts.length > 1 ? parts[1] : parts[0]

  const lookupPath = normalizePath(rawPath)

  // Router precedence: an exact literal path wins over a `{id}` template, so
  // `/payment_methods/types` resolves to itself and not to `/payment_methods/{id}`.
  const exact = collectMatches(spec, method, (specPath) => specPath === lookupPath)
  if (exact.length > 0) return exact
  return collectMatches(spec, method, (specPath) => pathMatches(specPath, lookupPath))
}

function collectMatches(
  spec: AdminSpec,
  method: string | undefined,
  pathMatcher: (shortPath: string) => boolean,
): SchemaResult[] {
  const matches: SchemaResult[] = []
  for (const [specPath, methods] of Object.entries(spec.paths)) {
    const shortPath = specPath.replace('/api/v3/admin', '') || '/'
    if (!pathMatcher(shortPath)) continue

    for (const [specMethod, operation] of Object.entries(methods)) {
      if (!HTTP_METHODS.has(specMethod)) continue
      if (method && specMethod !== method) continue

      matches.push({
        method: specMethod.toUpperCase(),
        path: shortPath,
        summary: operation.summary,
        description: operation.description,
        parameters: resolveRefs(operation.parameters, spec),
        requestBody: resolveRefs(operation.requestBody, spec),
        responses: resolveRefs(operation.responses, spec),
      })
    }
  }

  return matches
}

/** `/orders/{id}` matches `/orders/{id}` and `/orders/ord_x8k2J9aQ`. */
function pathMatches(specPath: string, lookupPath: string): boolean {
  if (specPath === lookupPath) return true

  const specSegments = specPath.split('/')
  const lookupSegments = lookupPath.split('/')
  if (specSegments.length !== lookupSegments.length) return false

  return specSegments.every((segment, i) => {
    if (segment.startsWith('{') && segment.endsWith('}')) return lookupSegments[i].length > 0
    return segment === lookupSegments[i]
  })
}

const MAX_REF_DEPTH = 8

/**
 * Inlines `$ref` pointers (only `#/components/schemas/*` appears in rswag
 * output). Depth-limited and cycle-safe: a re-entered or too-deep ref stays
 * as the raw pointer string.
 */
export function resolveRefs(node: unknown, spec: AdminSpec, seen: string[] = []): unknown {
  if (Array.isArray(node)) {
    return node.map((item) => resolveRefs(item, spec, seen))
  }
  if (!node || typeof node !== 'object') return node

  const record = node as Record<string, unknown>
  const ref = record.$ref
  if (typeof ref === 'string') {
    const name = ref.replace('#/components/schemas/', '')
    if (seen.includes(name) || seen.length >= MAX_REF_DEPTH || !(name in spec.components.schemas)) {
      return { $ref: ref }
    }
    return resolveRefs(spec.components.schemas[name], spec, [...seen, name])
  }

  const resolved: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(record)) {
    resolved[key] = resolveRefs(value, spec, seen)
  }
  return resolved
}
