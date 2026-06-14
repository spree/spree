/**
 * Generates the Admin API endpoint index page for the docs site.
 *
 * Usage: node packages/cli/scripts/generate-endpoints-doc.mjs
 *
 * Reads:  docs/api-reference/admin.yaml (rswag-generated)
 * Writes: docs/api-reference/admin-api/endpoints.mdx
 *
 * One row per operation — method, path, required scope, summary — grouped by
 * resource. The same data backs `spree api endpoints`; regenerate this page
 * whenever the Admin API surface or scope annotations change.
 */

import * as fs from 'node:fs'
import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from 'yaml'

const here = path.dirname(fileURLToPath(import.meta.url))
const SPEC_PATH = path.resolve(here, '../../../docs/api-reference/admin.yaml')
const OUT_PATH = path.resolve(here, '../../../docs/api-reference/admin-api/endpoints.mdx')

const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete']

const spec = parse(fs.readFileSync(SPEC_PATH, 'utf-8'))

function requiredScope(operation) {
  const match = operation.description?.match(
    /\*\*Required scope:\*\* (.+?) \(for API-key authentication\)\./s,
  )
  if (!match) return '—'
  const raw = match[1].replace(/\n/g, ' ').trim()
  const token = raw.match(/^`([a-z_]+)`$/)
  if (token) return `\`${token[1]}\``
  // Free-form note (e.g. exports resolve their scope per type) — keep it short.
  return `*${raw.replaceAll('`', '').split(' — ')[0]}*`
}

const groups = new Map()
for (const [specPath, methods] of Object.entries(spec.paths)) {
  const shortPath = specPath.replace('/api/v3/admin', '') || '/'
  const resource = shortPath.split('/')[1] || 'root'
  for (const method of HTTP_METHODS) {
    const operation = methods[method]
    if (!operation) continue
    if (!groups.has(resource)) groups.set(resource, [])
    groups.get(resource).push({
      method: method.toUpperCase(),
      path: shortPath,
      scope: requiredScope(operation),
      summary: operation.summary ?? '',
    })
  }
}

function title(resource) {
  return resource.replaceAll('_', ' ').replace(/^./, (c) => c.toUpperCase())
}

const sections = [...groups.entries()]
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([resource, rows]) => {
    const table = [
      '| Method | Path | Required scope | Summary |',
      '|---|---|---|---|',
      ...rows.map(
        (r) =>
          // Collapse any newlines/runs of whitespace in the summary so a
          // multi-line description can't break the Markdown table row.
          `| \`${r.method}\` | \`${r.path}\` | ${r.scope} | ${r.summary.replace(/\s+/g, ' ').trim().replaceAll('|', '\\|')} |`,
      ),
    ].join('\n')
    return `## ${title(resource)}\n\n${table}`
  })

const total = [...groups.values()].reduce((n, rows) => n + rows.length, 0)

const page = `---
title: "Admin API endpoint index"
sidebarTitle: "Endpoint index"
description: "Every Spree Admin API v3 endpoint at a glance — method, path, required API key scope, and summary, grouped by resource."
---

{/* Generated from docs/api-reference/admin.yaml by packages/cli/scripts/generate-endpoints-doc.mjs — do not edit by hand. */}

All ${total} Admin API operations, with the [scope](/api-reference/admin-api/authentication) a secret API key needs for each. JWT-authenticated admin users are governed by their roles instead of scopes. The same index is available offline via the CLI: \`spree api endpoints\`.

Endpoints marked — are exempt from scope checks (authentication and session endpoints) or resolve their scope at request time.

${sections.join('\n\n')}
`

fs.writeFileSync(OUT_PATH, page)
console.log(`endpoints.mdx written: ${total} operations, ${groups.size} resource groups`)
