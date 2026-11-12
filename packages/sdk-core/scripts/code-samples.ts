import { readdirSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from 'yaml'

const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete']

type CodeSample = { label?: string; source?: string }

/**
 * Lists the endpoints of an API reference (`docs/api-reference/<api>.yaml`)
 * that show no code sample with the given label, as `GET /api/v3/...`.
 */
export function endpointsWithoutSample(api: 'store' | 'admin' | 'seller', label: string): string[] {
  const specPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    `../../../docs/api-reference/${api}.yaml`,
  )
  const spec = parse(readFileSync(specPath, 'utf8'))
  const missing: string[] = []

  for (const [route, operations] of Object.entries<
    Record<string, { 'x-codeSamples'?: CodeSample[] }>
  >(spec.paths)) {
    for (const [method, operation] of Object.entries(operations)) {
      if (!HTTP_METHODS.includes(method)) continue

      const hasSample = operation['x-codeSamples']?.some(
        (sample) => sample.label === label && sample.source?.trim(),
      )
      if (!hasSample) missing.push(`${method.toUpperCase()} ${route}`)
    }
  }

  return missing
}

/**
 * Lists the example files under `examplesRoot` that lack the
 * `// region:example` … `// endregion:example` markers. The API reference
 * shows only the code between them, and a formatter can drop a trailing
 * marker along with the code around it.
 */
export function unmarkedExamples(examplesRoot: string): string[] {
  return readdirSync(examplesRoot, { recursive: true, encoding: 'utf8' })
    .filter((file) => file.endsWith('.ts'))
    .filter((file) => {
      const source = readFileSync(path.join(examplesRoot, file), 'utf8')
      const region = source.match(/\/\/ region:example\r?\n([\s\S]*?)\/\/ endregion:example/)
      return !region?.[1].trim()
    })
}
