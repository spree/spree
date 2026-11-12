import { readdirSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { describe, expect, it } from 'vitest'

// Every record page offers "View as JSON": a `PageHeader` given a `resource`
// also needs its `endpoint` or a custom `jsonPreview`.
const ROOTS = ['routes', 'components', '../../seller-dashboard/src/pages'].map((dir) =>
  path.resolve(import.meta.dirname, '..', dir),
)

function sourceFiles(dir: string): string[] {
  return readdirSync(dir, { recursive: true, encoding: 'utf8' })
    .filter((file) => file.endsWith('.tsx') && !file.includes('.test.'))
    .map((file) => path.join(dir, file))
}

// The formatter closes a multi-line element with `/>` at its opening indent.
function pageHeaders(source: string): string[] {
  const elements: string[] = []
  for (const match of source.matchAll(/^( *)<PageHeader\b/gm)) {
    const rest = source.slice(match.index)
    const close = rest.match(new RegExp(`^${match[1]}/>`, 'm'))
    const inline = rest.match(/^[^\n]*\/>/)
    elements.push(inline?.[0] ?? (close?.index ? rest.slice(0, close.index) : rest))
  }
  return elements
}

describe('PageHeader JSON view', () => {
  it('is wired on every page header that shows a record', () => {
    const headers = ROOTS.flatMap(sourceFiles).flatMap((file) =>
      pageHeaders(readFileSync(file, 'utf8'))
        .filter((element) => /\sresource=/.test(element))
        .map((element) => ({ file, element })),
    )
    const missing = headers.filter(({ element }) => !/\s(endpoint|jsonPreview)=/.test(element))

    // Guards against the scan silently matching nothing.
    expect(headers.length).toBeGreaterThan(20)
    expect(missing.map(({ file }) => path.relative(process.cwd(), file))).toEqual([])
  })
})
