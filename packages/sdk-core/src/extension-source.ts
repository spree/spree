// Renders the client of a package that extends Spree's SDKs: one extension
// per resource in an extension's OpenAPI document, each method calling one
// documented operation, named and shaped the way the SDKs' own methods are
// (`list`, `get`, `create`, `update`, `delete`, and the action, camel-cased:
// `PATCH /quotes/{id}/send` → `quotes.send(id, params)`). `spree sdk generate`
// writes it next to the request, filter and response types.

import type { ExtensionApi } from './extensions'

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
  summary?: string
  description?: string
  parameters?: { name: string; in: string }[]
  requestBody?: { required?: boolean; content?: Record<string, { schema?: Schema }> }
  responses?: Record<string, { content?: Record<string, { schema?: Schema }> }>
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
  doc: string[]
}

const camel = (value: string) => value.replace(/[_-](\w)/g, (_, c: string) => c.toUpperCase())
const pascal = (value: string) => camel(value).replace(/^\w/, (c) => c.toUpperCase())
const refName = (schema?: Schema) => schema?.$ref?.split('/').pop()

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

  for (const [path, item] of Object.entries(spec.paths ?? {})) {
    if (!path.startsWith(prefix)) continue
    const segments = path.slice(prefix.length).split('/')
    const resource = segments[0]
    for (const verb of VERBS) {
      const operation = item[verb]
      if (!operation) continue
      const method = methodFor(
        resource,
        segments.slice(1),
        verb,
        operation,
        path.slice(prefix.length - 1),
        options.types,
        filters,
      )
      const methods = resources.get(resource) ?? []
      const taken = methods.find(({ name }) => name === method.name)
      if (taken) {
        throw new Error(
          `${verb.toUpperCase()} ${method.path} and ${taken.verb.toUpperCase()} ${taken.path} would both be ${camel(resource)}.${method.name}; give one an operationId`,
        )
      }
      methods.push(method)
      resources.set(resource, methods)
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
  resource: string,
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

  const name = operation.operationId
    ? camel(operation.operationId)
    : defaultName(verb, statics, member, isList)

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
    response: responseType(resource, verb, operation, types),
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
  if (statics.length === 1 && !member) return camel(statics[0])
  // Deeper: the verb and the nested resource (`GET /orders/{id}/items` → `listItems`).
  return `${crud}${pascal(statics.join('_'))}`
}

function responseType(
  resource: string,
  verb: Verb,
  operation: Operation,
  types: Set<string>,
): string {
  const declared = ['200', '201']
    .map((status) => refName(operation.responses?.[status]?.content?.['application/json']?.schema))
    .find(Boolean)
  if (declared && types.has(declared)) return declared
  if (verb === 'delete' && !declared) return 'void'

  const byName = [pascal(singular(resource)), pascal(resource)].find((name) => types.has(name))
  return byName ?? 'unknown'
}

function render(
  resources: [string, Method[]][],
  api: ExtensionApi,
  options: ExtensionSourceOptions,
): string {
  const Api = pascal(api)
  const methods = resources.flatMap(([, list]) => list)
  const responseTypes = new Set(
    methods.map(({ response }) => response).filter((type) => type !== 'void' && type !== 'unknown'),
  )
  const bodyTypes = new Set(methods.flatMap(({ body }) => (body ? [body.type] : [])))
  const filterTables = new Set(methods.flatMap(({ filters }) => (filters ? [filters] : [])))
  const lists = methods.some(({ kind }) => kind === 'list')

  const sdkImports = [
    `define${Api}Extension`,
    'type Client',
    ...(lists ? ['type ListParams', 'type PaginatedResponse'] : []),
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
    method.kind === 'list' ? `PaginatedResponse<${method.response}>` : method.response
  const doc = method.doc.length
    ? ['  /**', ...method.doc.map((line) => `   * ${line}`.trimEnd()), '   */']
    : []
  return [
    ...doc,
    `  ${method.name}: (${args.join(', ')}): Promise<${response}> =>`,
    `    request<${response}>('${method.verb.toUpperCase()}', ${target}, ${request}),`,
  ]
}
