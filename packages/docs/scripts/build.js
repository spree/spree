/**
 * Converts Mintlify MDX docs to plain Markdown for AI agent consumption.
 *
 * - Strips Mintlify-specific JSX components (Info, Warning, Tabs, etc.)
 * - Inlines imported snippets
 * - Preserves frontmatter, code blocks, mermaid diagrams
 * - Outputs clean .md files to dist/
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from 'fs'
import { join, dirname, relative, resolve } from 'path'
import { convertContent, resolveImports, extractFrontmatter, rewriteLinks } from './convert.js'

const ROOT = resolve(import.meta.dirname, '..', '..', '..')
const DOCS_DIR = join(ROOT, 'docs')
const DIST_DIR = resolve(import.meta.dirname, '..', 'dist')

// Directories to include in the output
const INCLUDE_DIRS = [
  'developer',
  'api-reference',
  'integrations',
]

// Paths to exclude (relative to DOCS_DIR)
const EXCLUDE_PATHS = [
  'developer/storefront/rails',
]

// ---------------------------------------------------------------------------
// Snippet resolution (uses filesystem — not in convert.js)
// ---------------------------------------------------------------------------

const snippetCache = new Map()

function resolveSnippet(importPath) {
  const absPath = join(DOCS_DIR, importPath.replace(/^\//, ''))
  if (snippetCache.has(absPath)) return snippetCache.get(absPath)

  if (!existsSync(absPath)) {
    snippetCache.set(absPath, '')
    return ''
  }

  let content = readFileSync(absPath, 'utf-8')
  content = resolveImports(content, resolveSnippet)
  content = convertContent(content)
  snippetCache.set(absPath, content)
  return content
}

// ---------------------------------------------------------------------------
// File processing
// ---------------------------------------------------------------------------

function processFile(filePath) {
  let content = readFileSync(filePath, 'utf-8')

  const { frontmatter, body } = extractFrontmatter(content)
  const fileRelDir = dirname(relative(DOCS_DIR, filePath))

  let processed = body
  processed = resolveImports(processed, resolveSnippet)
  processed = convertContent(processed)
  processed = rewriteLinks(processed, fileRelDir)

  if (frontmatter) {
    processed = frontmatter + '\n' + processed.trim() + '\n'
  } else {
    processed = processed.trim() + '\n'
  }

  return processed
}

function walkDir(dir, fileList = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) {
      walkDir(full, fileList)
    } else if (entry.endsWith('.mdx') || entry.endsWith('.md')) {
      fileList.push(full)
    }
  }
  return fileList
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

let totalFiles = 0

for (const dir of INCLUDE_DIRS) {
  const sourceDir = join(DOCS_DIR, dir)
  if (!existsSync(sourceDir)) {
    console.warn(`Skipping ${dir}: directory not found`)
    continue
  }

  const files = walkDir(sourceDir)

  for (const file of files) {
    const rel = relative(DOCS_DIR, file)
    if (EXCLUDE_PATHS.some((ex) => rel.startsWith(ex))) continue
    const outPath = join(DIST_DIR, rel.replace(/\.mdx$/, '.md'))

    mkdirSync(dirname(outPath), { recursive: true })

    const converted = processFile(file)
    writeFileSync(outPath, converted)
    totalFiles++
  }
}

// ---------------------------------------------------------------------------
// Copy OpenAPI specs
// ---------------------------------------------------------------------------

const OPENAPI_FILES = [
  'api-reference/store.yaml',
]

for (const file of OPENAPI_FILES) {
  const src = join(DOCS_DIR, file)
  if (!existsSync(src)) {
    console.warn(`Skipping OpenAPI spec: ${file} not found`)
    continue
  }
  const dest = join(DIST_DIR, file)
  mkdirSync(dirname(dest), { recursive: true })
  writeFileSync(dest, readFileSync(src, 'utf-8'))
  totalFiles++
}

console.log(`@spree/docs: converted ${totalFiles} files to ${DIST_DIR}`)
