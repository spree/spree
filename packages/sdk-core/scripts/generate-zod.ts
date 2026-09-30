import * as fs from 'node:fs'
import * as path from 'node:path'

// Runs from the SDK package being generated (its `generate:zod` script), so the
// Store, Admin and Seller SDKs each turn their own generated types into schemas.
const TYPES_DIR = path.resolve(process.cwd(), 'src/types/generated')
const ZOD_DIR = path.resolve(process.cwd(), 'src/zod/generated')

interface FieldDef {
  name: string
  type: string
  optional: boolean
}

interface ParsedType {
  typeName: string
  fields: FieldDef[]
}

function parseTypeFile(content: string): ParsedType | null {
  const typeNameMatch = content.match(/^(?:type\s+(\w+)\s*=\s*\{|interface\s+(\w+)\s*\{)/m)
  if (!typeNameMatch) return null
  const typeName = typeNameMatch[1] || typeNameMatch[2]

  // Find the body between braces, handling nested braces (e.g., inline object types)
  const typeStart = content.indexOf(
    '{',
    content.search(/^(?:type\s+\w+\s*=\s*\{|interface\s+\w+\s*\{)/m),
  )
  if (typeStart === -1) return null
  let depth = 1
  let i = typeStart + 1
  while (i < content.length && depth > 0) {
    if (content[i] === '{') depth++
    else if (content[i] === '}') depth--
    i++
  }
  if (depth !== 0) return null
  const body = content
    .slice(typeStart + 1, i - 1)
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
  const fields: FieldDef[] = []
  for (const declaration of topLevelDeclarations(body)) {
    const match = declaration.match(/^(\w+)(\?)?\s*:\s*([\s\S]+)$/)
    if (!match) continue
    fields.push({
      name: match[1],
      type: match[3].replace(/\s+/g, ' ').trim(),
      optional: match[2] === '?',
    })
  }

  return { typeName, fields }
}

/**
 * Splits a type body into its own field declarations, keeping a field whose
 * type spans several lines (a nested object, a multi-line union) in one piece.
 */
function topLevelDeclarations(body: string): string[] {
  const declarations: string[] = []
  let current = ''
  let depth = 0

  const flush = () => {
    if (current.trim()) declarations.push(current.trim())
    current = ''
  }

  for (let index = 0; index < body.length; index++) {
    const character = body[index]
    if ('{<(['.includes(character)) depth++
    else if ('}>)]'.includes(character)) depth--

    if (depth === 0 && character === ';') {
      flush()
    } else if (depth === 0 && character === '\n') {
      const continuesOnNextLine = /[|:]\s*$/.test(current) || /^\s*\|/.test(body.slice(index + 1))
      if (continuesOnNextLine) current += ' '
      else flush()
    } else {
      current += character
    }
  }
  flush()

  return declarations
}

// Named enums (`Enums.ts`) are open string unions, so they validate as plain strings.
const enumTypeNames = new Set<string>()
const generatedTypeNames = new Set<string>()

type TypeNode =
  | { kind: 'keyword'; name: string }
  | { kind: 'literal'; value: string }
  | { kind: 'reference'; name: string }
  | { kind: 'array'; element: TypeNode }
  | { kind: 'record'; value: TypeNode }
  | { kind: 'object'; fields: Array<{ name: string; optional: boolean; type: TypeNode }> }
  | { kind: 'union'; members: TypeNode[] }

const KEYWORDS = new Set(['string', 'number', 'boolean', 'unknown', 'any', 'null'])

/**
 * Parses the subset of TypeScript type syntax Typelizer emits: keywords, string
 * literals, references, `Array<T>`, `T[]`, `Record<string, T>`, inline object
 * types and unions. Anything else throws, and the caller falls back to `z.any()`.
 */
function parseTypeExpression(source: string): TypeNode {
  const tokens = source.match(/'[^']*'|\w+|\[\]|[<>{}(),;:|?]/g) ?? []
  let position = 0

  const peek = () => tokens[position]
  const expect = (token: string) => {
    if (tokens[position] !== token) {
      throw new Error(`Expected "${token}" in "${source}"`)
    }
    position++
  }

  function parseUnion(): TypeNode {
    if (peek() === '|') position++
    const members = [parsePostfix()]
    while (peek() === '|') {
      position++
      members.push(parsePostfix())
    }
    return members.length === 1 ? members[0] : { kind: 'union', members }
  }

  function parsePostfix(): TypeNode {
    let node = parsePrimary()
    while (peek() === '[]') {
      position++
      node = { kind: 'array', element: node }
    }
    return node
  }

  function parsePrimary(): TypeNode {
    const token = tokens[position++]
    if (token === undefined) throw new Error(`Unexpected end of "${source}"`)
    if (token.startsWith("'")) return { kind: 'literal', value: token }
    if (token === '(') {
      const inner = parseUnion()
      expect(')')
      return inner
    }
    if (token === '{') return parseObjectBody()
    if (token === 'Array') {
      expect('<')
      const element = parseUnion()
      expect('>')
      return { kind: 'array', element }
    }
    if (token === 'Record') {
      expect('<')
      parseUnion()
      expect(',')
      const value = parseUnion()
      expect('>')
      return { kind: 'record', value }
    }
    if (KEYWORDS.has(token)) return { kind: 'keyword', name: token }
    if (/^[A-Z]\w*$/.test(token)) return { kind: 'reference', name: token }
    throw new Error(`Unsupported token "${token}" in "${source}"`)
  }

  function parseObjectBody(): TypeNode {
    const fields: Array<{ name: string; optional: boolean; type: TypeNode }> = []
    while (peek() !== '}') {
      const name = tokens[position++]
      if (name === undefined || !/^\w+$/.test(name)) {
        throw new Error(`Expected a field name in "${source}"`)
      }
      const optional = peek() === '?'
      if (optional) position++
      expect(':')
      fields.push({ name, optional, type: parseUnion() })
      if (peek() === ';' || peek() === ',') position++
    }
    expect('}')
    return { kind: 'object', fields }
  }

  const node = parseUnion()
  if (position !== tokens.length) throw new Error(`Unexpected "${peek()}" in "${source}"`)
  return node
}

function collectReferences(node: TypeNode, references: Set<string>): void {
  switch (node.kind) {
    case 'reference':
      if (generatedTypeNames.has(node.name)) references.add(node.name)
      break
    case 'array':
      collectReferences(node.element, references)
      break
    case 'record':
      collectReferences(node.value, references)
      break
    case 'object':
      for (const field of node.fields) collectReferences(field.type, references)
      break
    case 'union':
      for (const member of node.members) collectReferences(member, references)
      break
  }
}

function nodeToZod(node: TypeNode, referencedTypes: Set<string>, cyclicTypes: Set<string>): string {
  switch (node.kind) {
    case 'keyword':
      return `z.${node.name}()`
    case 'literal':
      // A lone literal is a discriminator (`type: 'price_range'`), which a union needs to tell its members apart.
      return `z.literal(${node.value})`
    case 'reference':
      if (enumTypeNames.has(node.name)) return 'z.string()'
      if (!generatedTypeNames.has(node.name)) return 'z.any()'
      referencedTypes.add(node.name)
      return `${node.name}Schema`
    case 'array':
      return `z.array(${nodeToZod(node.element, referencedTypes, cyclicTypes)})`
    case 'record':
      return `z.record(z.string(), ${nodeToZod(node.value, referencedTypes, cyclicTypes)})`
    case 'object': {
      const fields = node.fields.map((field) => {
        const expression = nodeToZod(field.type, referencedTypes, cyclicTypes)
        return `${field.name}: ${expression}${field.optional ? '.optional()' : ''}`
      })
      return `z.object({ ${fields.join(', ')} })`
    }
    case 'union': {
      const nullable = node.members.some((m) => m.kind === 'keyword' && m.name === 'null')
      const members = node.members.filter((m) => !(m.kind === 'keyword' && m.name === 'null'))
      let expression: string
      if (members.every((m) => m.kind === 'literal')) {
        // Literal unions are enums the server may extend, so any string is accepted.
        expression = 'z.string()'
      } else if (members.length === 1) {
        expression = nodeToZod(members[0], referencedTypes, cyclicTypes)
      } else {
        const zodMembers = members.map((m) => nodeToZod(m, referencedTypes, cyclicTypes))
        expression = `z.union([${zodMembers.join(', ')}])`
      }
      return nullable ? `${expression}.nullable()` : expression
    }
  }
}

function typeToZod(
  typeStr: string,
  referencedTypes: Set<string>,
  cyclicTypes: Set<string>,
): string {
  try {
    return nodeToZod(parseTypeExpression(typeStr), referencedTypes, cyclicTypes)
  } catch (error) {
    console.warn(`Falling back to z.any(): ${(error as Error).message}`)
    return 'z.any()'
  }
}

function generateZodFile(parsed: ParsedType, cyclicTypes: Set<string>): string {
  const referencedTypes = new Set<string>()
  const fieldLines: string[] = []

  for (const field of parsed.fields) {
    const fieldReferences = new Set<string>()
    let zodExpr = typeToZod(field.type, fieldReferences, cyclicTypes)
    if (field.optional) zodExpr += '.optional()'
    for (const reference of fieldReferences) referencedTypes.add(reference)

    // A field reaching back into a reference cycle is a getter, so the schema it
    // points at is read on first parse rather than while the modules load.
    const closesCycle = [...fieldReferences].some((reference) => cyclicTypes.has(reference))
    fieldLines.push(
      closesCycle
        ? `  get ${field.name}() { return ${zodExpr}; },`
        : `  ${field.name}: ${zodExpr},`,
    )
  }

  const refImports = Array.from(referencedTypes)
    .filter((ref) => ref !== parsed.typeName)
    .sort()
    .map((ref) => `import { ${ref}Schema } from './${ref}';`)

  const schemaDecl = `export const ${parsed.typeName}Schema = z.object({`

  const lines: string[] = [
    '// This file is auto-generated. Do not edit directly.',
    "import { z } from 'zod';",
    ...refImports,
    '',
    schemaDecl,
    ...fieldLines,
    '});',
    '',
    `export type ${parsed.typeName} = z.infer<typeof ${parsed.typeName}Schema>;`,
    '',
  ]

  return lines.join('\n')
}

/** Extract type references from field types */
function extractTypeRefs(fields: FieldDef[]): Set<string> {
  const refs = new Set<string>()
  for (const field of fields) {
    try {
      collectReferences(parseTypeExpression(field.type), refs)
    } catch {
      // Unparseable fields become z.any() and reference nothing.
    }
  }
  return refs
}

/** Detect all types involved in circular dependencies */
function detectCyclicTypes(parsedTypes: Map<string, ParsedType>): Set<string> {
  const deps = new Map<string, Set<string>>()
  for (const [name, parsed] of parsedTypes) {
    deps.set(name, extractTypeRefs(parsed.fields))
  }

  const cyclic = new Set<string>()
  const visited = new Set<string>()
  const inStack = new Set<string>()

  function dfs(node: string, path: string[]): void {
    if (inStack.has(node)) {
      // Found a cycle — mark all nodes in the cycle
      const cycleStart = path.indexOf(node)
      for (let i = cycleStart; i < path.length; i++) {
        cyclic.add(path[i])
      }
      return
    }
    if (visited.has(node)) return

    visited.add(node)
    inStack.add(node)
    path.push(node)

    for (const dep of deps.get(node) ?? []) {
      if (deps.has(dep)) {
        dfs(dep, path)
      }
    }

    path.pop()
    inStack.delete(node)
  }

  for (const name of deps.keys()) {
    dfs(name, [])
  }

  return cyclic
}

function main(): void {
  if (fs.existsSync(ZOD_DIR)) {
    fs.rmSync(ZOD_DIR, { recursive: true })
  }
  fs.mkdirSync(ZOD_DIR, { recursive: true })

  const files = fs
    .readdirSync(TYPES_DIR)
    .filter((f) => f.endsWith('.ts') && f !== 'index.ts' && f !== 'Enums.ts')
    .sort()

  const enumsFile = path.join(TYPES_DIR, 'Enums.ts')
  if (fs.existsSync(enumsFile)) {
    for (const m of fs.readFileSync(enumsFile, 'utf-8').matchAll(/^export type (\w+) =/gm)) {
      enumTypeNames.add(m[1])
    }
  }

  // First pass: parse all type files
  const parsedTypes = new Map<string, ParsedType>()
  for (const file of files) {
    const filePath = path.join(TYPES_DIR, file)
    const content = fs.readFileSync(filePath, 'utf-8')
    const parsed = parseTypeFile(content)
    if (!parsed) {
      console.warn(`Skipping ${file}: could not parse type definition`)
      continue
    }
    parsedTypes.set(parsed.typeName, parsed)
    generatedTypeNames.add(parsed.typeName)
  }

  // Detect cycles
  const cyclicTypes = detectCyclicTypes(parsedTypes)
  if (cyclicTypes.size > 0) {
    console.log(`Detected circular dependencies: ${Array.from(cyclicTypes).join(', ')}`)
    console.log('Using getters for these references.\n')
  }

  const generatedNames: string[] = []

  for (const [, parsed] of parsedTypes) {
    fs.writeFileSync(
      path.join(ZOD_DIR, `${parsed.typeName}.ts`),
      generateZodFile(parsed, cyclicTypes),
      'utf-8',
    )
    generatedNames.push(parsed.typeName)
    console.log(`Generated: ${parsed.typeName}.ts`)
  }

  const indexLines = [
    '// This file is auto-generated. Do not edit directly.',
    ...generatedNames.map((n) => `export { ${n}Schema, type ${n} } from './${n}';`),
    '',
  ]
  fs.writeFileSync(path.join(ZOD_DIR, 'index.ts'), indexLines.join('\n'), 'utf-8')
  console.log(`\nGenerated barrel: index.ts (${generatedNames.length} schemas)`)
}

main()
