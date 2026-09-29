import { readFileSync } from 'node:fs'
import path from 'node:path'
import { parse } from 'yaml'
import type { ZodType } from 'zod'

interface OpenApiExample {
  /** `GET /api/v3/admin/products` — where the example was recorded. */
  endpoint: string
  /** The component schema the response declares for this record. */
  schemaName: string
  record: unknown
}

type SchemaReference = { $ref?: string }
type ResponseSchema = SchemaReference & {
  properties?: { data?: SchemaReference & { items?: SchemaReference } }
}

const referencedName = (reference?: string) => reference?.split('/').pop()

/**
 * Collects every successful response example recorded in an API reference
 * (`docs/api-reference/<api>.yaml`) together with the schema it declares, one
 * entry per record — list responses contribute each item of `data`.
 *
 * The examples are real responses captured by the integration specs, so
 * validating them against the generated Zod schemas proves the schemas accept
 * what the API actually returns.
 */
function openApiExamples(api: 'store' | 'admin' | 'seller'): OpenApiExample[] {
  const specPath = path.resolve(import.meta.dirname, `../../../docs/api-reference/${api}.yaml`)
  const spec = parse(readFileSync(specPath, 'utf8'))
  const examples: OpenApiExample[] = []

  for (const [route, operations] of Object.entries<Record<string, unknown>>(spec.paths)) {
    for (const [method, operation] of Object.entries(operations)) {
      const responses = (operation as { responses?: Record<string, unknown> })?.responses ?? {}

      for (const [status, response] of Object.entries(responses)) {
        if (!status.startsWith('2')) continue

        const content = (
          response as { content?: Record<string, { example?: unknown; schema?: ResponseSchema }> }
        ).content?.['application/json']
        if (!content?.example) continue

        const endpoint = `${method.toUpperCase()} ${route}`
        const schema = content.schema ?? {}
        const data = schema.properties?.data
        const example = content.example as { data?: unknown }

        if (schema.$ref) {
          examples.push({ endpoint, schemaName: referencedName(schema.$ref)!, record: example })
        } else if (data?.$ref) {
          examples.push({ endpoint, schemaName: referencedName(data.$ref)!, record: example.data })
        } else if (data?.items?.$ref && Array.isArray(example.data)) {
          for (const record of example.data) {
            examples.push({ endpoint, schemaName: referencedName(data.items.$ref)!, record })
          }
        }
      }
    }
  }

  return examples
}

/**
 * Validates every recorded API reference example against the matching generated
 * schema and returns a readable line per rejection (empty when all pass), plus
 * how many examples were checked so a spec can guard against checking nothing.
 */
export function rejectedExamples(
  api: 'store' | 'admin' | 'seller',
  schemas: Record<string, unknown>,
): { checked: number; rejections: string[] } {
  let checked = 0
  const rejections: string[] = []

  for (const { endpoint, schemaName, record } of openApiExamples(api)) {
    const schema = schemas[`${schemaName}Schema`] as ZodType | undefined
    if (!schema) continue

    checked++
    const result = schema.safeParse(record)
    if (!result.success) {
      const issues = result.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      rejections.push(`${endpoint} → ${schemaName}: ${issues.join('; ')}`)
    }
  }

  return { checked, rejections }
}
