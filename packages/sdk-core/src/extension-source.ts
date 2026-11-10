// Renders the client of a package that extends Spree's SDKs: one extension
// per resource in an extension's OpenAPI document, each method calling one
// documented operation, named and shaped the way the SDKs' own methods are
// (`list`, `get`, `create`, `update`, `delete`, and the action, camel-cased:
// `PATCH /quotes/{id}/send` → `quotes.send(id, params)`). `spree sdk generate`
// writes it next to the request, filter and response types.

import type { ExtensionApi } from './extensions'
import { type ParamsSchema, schemaType } from './params-types'

const SDKS: Record<ExtensionApi, string> = {
  store: '@spree/sdk',
  admin: '@spree/admin-sdk',
  seller: '@spree/seller-sdk',
}

const VERBS = ['get', 'post', 'put', 'patch', 'delete'] as const
type Verb = (typeof VERBS)[number]

interface Schema {
  $ref?: string
}

interface Operation {
  operationId?: string
  /** The SDK method's name, apart from `operationId`, which also names the agent tool. */
  'x-spree-sdk-method'?: string
  /** The namespace the method goes in, instead of the path's resource. */
  'x-spree-sdk-namespace'?: string
  summary?: string
  description?: string
  parameters?: { name: string; in: string }[]
  requestBody?: { required?: boolean; content?: Record<string, { schema?: Schema }> }
  responses?: Record<string, { content?: Record<string, { schema?: ParamsSchema }> }>
  'x-spree-filters'?: { table: string }
}

export interface ExtensionSpec {
  paths?: Record<string, Partial<Record<Verb, Operation>>>
  components?: { 'x-spree-filter-tables'?: Record<string, unknown> }
}

export interface ExtensionSourceOptions {
  /** The first line of the file, saying how it was generated. */
  header: string
  /**
   * The response types the package has (`rake spree:sdk:serializer_types`),
   * imported from `./spree`. A response with no declared schema is typed by
   * the resource's name (`quotes` → `Quote`) when the package has that type.
   */
  types: Set<string>
}

interface Method {
  name: string
  verb: Verb
  path: string
  pathParams: string[]
  kind: 'list' | 'read' | 'body' | 'plain'
  body?: { type: string; required: boolean }
  filters?: string
  response: string
  /** A response declared inline: its type, written above the extensions. */
  responseType?: { name: string; source: string; references: string[] }
  doc: string[]
}

const camel = (value: string) => value.replace(/[_-](\w)/g, (_, c: string) => c.toUpperCase())
const pascal = (value: string) => camel(value).replace(/^\w/, (c) => c.toUpperCase())
const refName = (schema?: Schema) => schema?.$ref?.split('/').pop()
const IDENTIFIER = /^[A-Za-z_$][\w$]*$/
// Words `export const <name>` cannot take.
const RESERVED = new Set(
  'arguments await break case catch class const continue debugger default delete do else enum eval export extends false finally for function if implements import in instanceof interface let new null package private protected public return static super switch this throw true try typeof var void while with yield'.split(
    ' ',
  ),
)

function singular(word: string): string {
  if (word.endsWith('ies')) return `${word.slice(0, -3)}y`
  if (/(ss|sh|ch|x)es$/.test(word)) return word.slice(0, -2)
  if (word.endsWith('s') && !word.endsWith('ss')) return word.slice(0, -1)
  return word
}

/**
 * @param spec an extension's `openapi/<api>.yaml`, parsed
 * @param api the API the document describes
 * @returns the TypeScript source, or undefined when it documents no operation
 */
export function renderExtensionSource(
  spec: ExtensionSpec,
  api: ExtensionApi,
  options: ExtensionSourceOptions,
): string | undefined {
  const prefix = `/api/v3/${api}/`
  const filters = Boolean(spec.components?.['x-spree-filter-tables'])
  const resources = new Map<string, Method[]>()
  const inlineNames = new Map<string, string>()

  for (const [path, item] of Object.entries(spec.paths ?? {})) {
    if (!path.startsWith(prefix)) continue
    const segments = path.slice(prefix.length).split('/')
    const resource = segments[0]
    for (const verb of VERBS) {
      const operation = item[verb]
      if (!operation) continue
      // Camel-cased as read, so `quote_notes` and `quoteNotes` are one namespace.
      const namespace = camel(operation['x-spree-sdk-namespace'] ?? resource)
      if (!IDENTIFIER.test(namespace) || RESERVED.has(namespace)) {
        throw new Error(
          `${verb.toUpperCase()} ${path} would be the namespace ${namespace}, which is not an identifier; name one with x-spree-sdk-namespace (\`sdk_method namespace:\` in its rswag spec)`,
        )
      }
      const method = methodFor(
        { resource, namespace },
        segments.slice(1),
        verb,
        operation,
        path.slice(prefix.length - 1),
        options.types,
        filters,
      )
      const methods = resources.get(namespace) ?? []
      const taken = methods.find(({ name }) => name === method.name)
      if (taken) {
        throw new Error(
          `${verb.toUpperCase()} ${method.path} and ${taken.verb.toUpperCase()} ${taken.path} would both be ${namespace}.${method.name}; name one with x-spree-sdk-method (\`sdk_method\` in its rswag spec)`,
        )
      }
      const inline = method.responseType?.name
      if (inline) {
        const other = inlineNames.get(inline)
        if (other || options.types.has(inline)) {
          throw new Error(
            `${verb.toUpperCase()} ${method.path} would declare the response type ${inline}, which ${other ? `${other} declares too` : 'the package already has'}; rename the method with x-spree-sdk-method`,
          )
        }
        inlineNames.set(inline, `${verb.toUpperCase()} ${method.path}`)
      }
      methods.push(method)
      resources.set(namespace, methods)
    }
  }
  if (resources.size === 0) return undefined

  return render(
    [...resources].sort(([a], [b]) => a.localeCompare(b)),
    api,
    options,
  )
}

function methodFor(
  { resource, namespace }: { resource: string; namespace: string },
  tail: string[],
  verb: Verb,
  operation: Operation,
  path: string,
  types: Set<string>,
  filters: boolean,
): Method {
  const pathParams = [...path.matchAll(/\{(\w+)\}/g)].map((match) => camel(match[1]))
  const statics = tail.filter((segment) => !segment.startsWith('{'))
  const member = tail.length > 0 && tail[tail.length - 1].startsWith('{')
  const queryNames = (operation.parameters ?? []).filter((p) => p.in === 'query').map((p) => p.name)
  const isList =
    verb === 'get' &&
    !member &&
    (Boolean(operation['x-spree-filters']) || queryNames.includes('page'))

  const given = operation['x-spree-sdk-method'] ?? operation.operationId
  const name = given ? camel(given) : defaultName(verb, statics, member, isList)

  const bodySchema = operation.requestBody?.content?.['application/json']?.schema
  const bodyType = refName(bodySchema)
  const body = bodyType
    ? { type: bodyType, required: operation.requestBody?.required ?? false }
    : undefined
  const kind = isList ? 'list' : verb === 'get' ? 'read' : body ? 'body' : 'plain'

  return {
    name,
    verb,
    path,
    pathParams,
    kind,
    body,
    filters: isList && filters ? operation['x-spree-filters']?.table : undefined,
    ...responseType(
      resource,
      `${pascal(namespace)}${pascal(name)}Response`,
      verb,
      operation,
      types,
    ),
    // `*/` in a description would end the doc comment early.
    doc: [operation.summary, operation.description]
      .filter((text): text is string => Boolean(text))
      .map((text) => text.trim().replaceAll('*/', '*\\/'))
      .join('\n\n')
      .split('\n'),
  }
}

/** The context helpers a namespace's methods use. */
function helpersFor(methods: Method[]): string[] {
  return [
    'request',
    ...(methods.some(({ kind }) => kind === 'list') ? ['listParams'] : []),
    ...(methods.some(({ kind }) => kind === 'read') ? ['readParams'] : []),
  ]
}

const CRUD: Record<Verb, string> = {
  get: 'get',
  post: 'create',
  put: 'update',
  patch: 'update',
  delete: 'delete',
}

function defaultName(verb: Verb, statics: string[], member: boolean, isList: boolean): string {
  const crud = isList ? 'list' : CRUD[verb]
  // `/quotes`, `/quotes/{id}`, `/quote_settings`: the SDKs' CRUD names.
  if (statics.length === 0) return crud
  // `/quotes/{id}/send`, `/quotes/statuses`: the action.
  if (statics.length === 1 && !member && !isList) return camel(statics[0])
  // Deeper: the verb and the nested resource (`GET /orders/{id}/items` → `listItems`).
  return `${crud}${pascal(statics.join('_'))}`
}

function responseType(
  resource: string,
  inlineName: string,
  verb: Verb,
  operation: Operation,
  types: Set<string>,
): Pick<Method, 'response' | 'responseType'> {
  const schema = ['200', '201']
    .map((status) => operation.responses?.[status]?.content?.['application/json']?.schema)
    .find(Boolean)
  const declared = refName(schema)
  if (declared && types.has(declared)) return { response: declared }

  // An inline schema (`{ data: [...] }`, not one of the package's records)
  // is typed from the schema itself.
  const inlineSchema =
    schema?.type ||
    schema?.properties ||
    schema?.allOf ||
    schema?.anyOf ||
    schema?.oneOf ||
    schema?.enum
  if (schema && !schema.$ref && inlineSchema) {
    const references = new Set<string>()
    const source = schemaType(schema, (ref) => {
      const name = refName({ $ref: ref }) ?? ''
      if (!types.has(name)) return 'unknown'
      references.add(name)
      return name
    })
    return {
      response: inlineName,
      responseType: { name: inlineName, source, references: [...references] },
    }
  }
  if (verb === 'delete' && !declared) return { response: 'void' }

  const byName = [pascal(singular(resource)), pascal(resource)].find((name) => types.has(name))
  return { response: byName ?? 'unknown' }
}

function render(
  resources: [string, Method[]][],
  api: ExtensionApi,
  options: ExtensionSourceOptions,
): string {
  const Api = pascal(api)
  const methods = resources.flatMap(([, list]) => list)
  const inline = methods.flatMap(({ responseType }) => (responseType ? [responseType] : []))
  const inlineNames = new Set(inline.map(({ name }) => name))
  const responseTypes = new Set([
    ...methods
      .map(({ response }) => response)
      .filter((type) => type !== 'void' && type !== 'unknown' && !inlineNames.has(type)),
    ...inline.flatMap(({ references }) => references),
  ])
  const bodyTypes = new Set(methods.flatMap(({ body }) => (body ? [body.type] : [])))
  const filterTables = new Set(methods.flatMap(({ filters }) => (filters ? [filters] : [])))
  const lists = methods.some(({ kind }) => kind === 'list')

  const sdkImports = [
    `define${Api}Extension`,
    'type Client',
    ...(lists ? ['type ListParams'] : []),
    // An inline response already describes the whole list, `meta` included.
    ...(methods.some(({ kind, responseType }) => kind === 'list' && !responseType)
      ? ['type PaginatedResponse']
      : []),
    'type RequestOptions',
  ]
  const out = [options.header, '', `import { ${sdkImports.join(', ')} } from '${SDKS[api]}'`]
  if (filterTables.size) {
    const names = [...filterTables].sort().flatMap((table) => [`${table}Filters`, `${table}Sort`])
    out.push(`import type { ${names.join(', ')} } from './filters'`)
  }
  if (bodyTypes.size)
    out.push(`import type { ${[...bodyTypes].sort().join(', ')} } from './params'`)
  if (responseTypes.size)
    out.push(`import type { ${[...responseTypes].sort().join(', ')} } from './spree'`)

  for (const { name, source } of inline) out.push('', `export type ${name} = ${source}`)

  const constants: string[] = []
  for (const [resource, list] of resources) {
    const constant = camel(resource)
    constants.push(constant)
    out.push(
      '',
      `export const ${constant} = define${Api}Extension('${constant}', ({ ${helpersFor(list).join(', ')} }) => ({`,
    )
    for (const method of list) out.push(...renderMethod(method), '')
    out.pop()
    out.push('}))')
  }

  out.push(
    '',
    `/** Adds every namespace above to a client: \`extend${Api}Client(createClient(…))\`. */`,
    `export const extend${Api}Client = <C extends Client>(client: C) =>`,
    `  client${constants.map((constant) => `.extend(${constant})`).join('')}`,
    '',
  )
  return out.join('\n')
}

function renderMethod(method: Method): string[] {
  const args = method.pathParams.map((param) => `${param}: string`)
  let request: string
  const target = `\`${method.path.replace(/\{(\w+)\}/g, (_, name: string) => `\${${camel(name)}}`)}\``

  if (method.kind === 'list') {
    const listType = method.filters
      ? `ListParams<${method.filters}Filters, ${method.filters}Sort>`
      : 'ListParams'
    args.push(`params?: ${listType}`)
    request = `{ ...options, params: params ? listParams(params) : undefined }`
  } else if (method.kind === 'read') {
    args.push('params?: { expand?: string[] }')
    request = '{ ...options, params: readParams(params) }'
  } else if (method.body) {
    args.push(`params${method.body.required ? '' : '?'}: ${method.body.type}`)
    request = '{ ...options, body: params }'
  } else {
    request = 'options'
  }
  args.push('options?: RequestOptions')

  const response =
    method.kind === 'list' && !method.responseType
      ? `PaginatedResponse<${method.response}>`
      : method.response
  const doc = method.doc.length
    ? ['  /**', ...method.doc.map((line) => `   * ${line}`.trimEnd()), '   */']
    : []
  return [
    ...doc,
    `  ${method.name}: (${args.join(', ')}): Promise<${response}> =>`,
    `    request<${response}>('${method.verb.toUpperCase()}', ${target}, ${request}),`,
  ]
}
