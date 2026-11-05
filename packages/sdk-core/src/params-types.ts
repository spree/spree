// Renders the request body types each SDK publishes, generated from the
// request schemas in its API reference (`pnpm generate:params`). Those schemas
// come from the controllers' `request_params` declarations, the same ones the
// API permits from, so the types say exactly what an endpoint accepts.

const HEADER =
  '// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.\n'

export interface ParamsSchema {
  type?: string
  format?: string
  enum?: (string | number | boolean)[]
  nullable?: boolean
  deprecated?: boolean
  description?: string
  properties?: Record<string, ParamsSchema>
  required?: string[]
  additionalProperties?: boolean | ParamsSchema
  items?: ParamsSchema
  allOf?: ParamsSchema[]
  anyOf?: ParamsSchema[]
  oneOf?: ParamsSchema[]
  $ref?: string
}

export interface ParamsSpec {
  components?: { schemas?: Record<string, ParamsSchema> }
}

/**
 * Output for an extension's own package rather than an SDK in this
 * repository (`spree sdk types`).
 */
export interface ExtensionTypesOptions {
  /** The first line of every file, saying how it was generated. */
  header: string
  /** The SDK whose shared types the files import (`@spree/admin-sdk`). */
  sdk: string
}

const isRequestSchema = (name: string) => name.endsWith('Params')

// Code lists the request schemas reference by name: ISO countries and
// currencies, Spree's locales, time zones and measurement units. The response types
// generated beside these files declare the same named types, so a request
// imports them from there rather than repeating them.
const SHARED_CODE_LISTS = new Set([
  'CountryCode',
  'CurrencyCode',
  'LocaleCode',
  'TimeZone',
  'WeightUnit',
  'DimensionUnit',
])

function refName(ref: string): string {
  const name = ref.replace('#/components/schemas/', '')
  if (!isRequestSchema(name) && !SHARED_CODE_LISTS.has(name)) {
    throw new Error(`A request schema references ${name}, which is not a request schema`)
  }
  return name
}

function quoteKey(key: string): string {
  return /^[A-Za-z_$][\w$]*$/.test(key) ? key : literal(key)
}

const LINE_WIDTH = 100

function wrap(text: string, width: number): string[] {
  const lines: string[] = []
  for (const paragraph of text.trim().split('\n')) {
    let line = ''
    // A `code span` is one word, so a line never breaks inside it.
    for (const word of paragraph.match(/(?:`[^`]*`|[^\s`])+/g) ?? []) {
      if (line && line.length + word.length + 1 > width) {
        lines.push(line)
        line = word
      } else {
        line = line ? `${line} ${word}` : word
      }
    }
    lines.push(line)
  }
  return lines
}

function docComment(description: string | undefined, indent: string): string[] {
  if (!description) return []
  const text = description.replaceAll('*/', '*\\/')
  if (indent.length + text.length + 7 <= LINE_WIDTH && !text.includes('\n')) {
    return [`${indent}/** ${text} */`]
  }
  return [
    `${indent}/**`,
    ...wrap(text, LINE_WIDTH - indent.length - 3).map(
      (line) => `${indent} *${line ? ` ${line}` : ''}`,
    ),
    `${indent} */`,
  ]
}

// The reference says why a field is deprecated at the end of its description
// (`Deprecated: Use country_code.`); TypeScript wants that in the tag, which
// editors show and strike the field through for.
function propertyDoc(property: ParamsSchema): string | undefined {
  if (!property.deprecated) return property.description
  const [text, note] = (property.description ?? '').split(/\s*Deprecated: /)
  return [text, `@deprecated ${note ?? ''}`.trimEnd()].filter(Boolean).join('\n')
}

const literal = (value: string) => `'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'`

type RefResolver = (ref: string) => string

function valueType(schema: ParamsSchema, indent: string, ref: RefResolver = refName): string {
  let type: string
  if (schema.$ref) {
    type = ref(schema.$ref)
  } else if (schema.allOf) {
    // A union part is parenthesized, or `&` would bind to its last member only.
    type = schema.allOf
      .map((part) => {
        const partType = valueType(part, indent, ref)
        return partType.includes(' | ') && !partType.startsWith('{') ? `(${partType})` : partType
      })
      .join(' & ')
  } else if (schema.anyOf) {
    // An open list: the built-in values, plus any other string an extension
    // adds, which `(string & {})` accepts without swallowing autocompletion.
    type = schema.anyOf
      .map((part) => {
        if (part.enum) return valueType(part, indent, ref)
        // `null` stays outside `& {}`, which would reduce it to `never`.
        const open = `(${valueType({ ...part, nullable: false }, indent, ref)} & {})`
        return part.nullable ? `${open} | null` : open
      })
      .join(' | ')
  } else if (schema.oneOf) {
    type = schema.oneOf.map((part) => valueType(part, indent, ref)).join(' | ')
  } else if (schema.enum) {
    type = schema.enum
      .map((value) => (typeof value === 'string' ? literal(value) : String(value)))
      .join(' | ')
  } else if (schema.type === 'array') {
    const item = valueType(schema.items ?? {}, indent, ref)
    type = /[|& ]/.test(item) && !item.startsWith('{') ? `Array<${item}>` : `${item}[]`
  } else if (schema.type === 'object' || schema.properties) {
    if (schema.properties) {
      type = objectType(schema, indent, ref)
    } else if (typeof schema.additionalProperties === 'object') {
      type = `Record<string, ${valueType(schema.additionalProperties, indent, ref)}>`
    } else {
      type = 'Record<string, unknown>'
    }
  } else if (schema.type === 'string' || schema.type === 'boolean') {
    type = schema.type
  } else if (schema.type === 'integer' || schema.type === 'number') {
    type = 'number'
  } else {
    type = 'unknown'
  }
  return schema.nullable && type !== 'unknown' ? `${type} | null` : type
}

function objectType(schema: ParamsSchema, indent: string, ref: RefResolver = refName): string {
  const inner = `${indent}  `
  const required = new Set(schema.required ?? [])
  const lines = ['{']
  for (const [key, property] of Object.entries(schema.properties ?? {})) {
    lines.push(...docComment(propertyDoc(property), inner))
    lines.push(
      `${inner}${quoteKey(key)}${required.has(key) ? '' : '?'}: ${valueType(property, inner, ref)}`,
    )
  }
  lines.push(`${indent}}`)
  return lines.join('\n')
}

function references(schema: ParamsSchema, found = new Set<string>()): Set<string> {
  if (schema.$ref) found.add(refName(schema.$ref))
  for (const part of schema.allOf ?? []) references(part, found)
  for (const property of Object.values(schema.properties ?? {})) references(property, found)
  if (schema.items) references(schema.items, found)
  return found
}

/**
 * A schema an operation declares inline (a response that is not one of the
 * package's records), as a TypeScript type. `ref` names the type a `$ref`
 * points at.
 */
export function schemaType(schema: ParamsSchema, ref: RefResolver): string {
  return valueType(schema, '', ref)
}

/**
 * One file per request type, plus an `index.ts` re-exporting them all, the
 * same layout Typelizer writes the response types in.
 *
 * @param spec - an API reference, parsed
 * @param extension - write for an extension's package instead of an SDK
 * @returns file name → TypeScript source
 */
export function renderParamsTypes(
  spec: ParamsSpec,
  extension?: ExtensionTypesOptions,
): Map<string, string> {
  const header = extension ? `${extension.header}\n` : HEADER
  // The SDKs keep the code lists next to their params; an extension imports
  // them from the SDK it extends.
  const codeLists = extension?.sdk ?? '../generated'
  const schemas = spec.components?.schemas ?? {}
  const names = Object.keys(schemas).filter(isRequestSchema).sort()
  const files = new Map<string, string>()

  for (const name of names) {
    // Each name becomes a file name and a type name, so anything but an
    // identifier would write outside the output folder or break the file.
    if (!/^[A-Za-z_$][\w$]*$/.test(name)) {
      throw new Error(`${name} is not a request type name an API reference can declare`)
    }
    const schema = schemas[name]
    const out = [header]
    const imports = [...references(schema)].filter((reference) => reference !== name).sort()
    for (const reference of imports) {
      const from = SHARED_CODE_LISTS.has(reference) ? codeLists : `./${reference}`
      out.push(`import type { ${reference} } from '${from}'`)
    }
    if (imports.length) out.push('')
    out.push(...docComment(schema.description, ''))
    out.push(
      `export type ${name} = ${schema.allOf ? valueType(schema, '') : objectType(schema, '')}`,
    )
    files.set(`${name}.ts`, `${out.join('\n')}\n`)
  }

  const index = [header, ...names.map((name) => `export type { ${name} } from './${name}'`)]
  files.set('index.ts', `${index.join('\n')}\n`)
  return files
}
