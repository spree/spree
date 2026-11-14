import { deployConfig, reportHasFailures } from './apply.js'
import { parseConfig, type Variables } from './load.js'
import { renderReport } from './render.js'
import type { ConfigClient, LiveRecord } from './types.js'

/**
 * A recipe sets a store up in steps that have to happen in order: deploy a
 * store file, import a CSV that builds on it, deploy the file that builds on
 * the import. Every step goes through the Admin API and is safe to repeat,
 * so a recipe that stopped halfway is finished by running it again.
 */

/** The Admin API client a recipe needs: requests, and file uploads for its imports. */
export interface RecipeClient extends ConfigClient {
  files: {
    upload: (
      file: Blob,
      options?: {
        visibility?: 'public' | 'private'
        filename?: string
        contentType?: string
        method?: 'presigned' | 'multipart'
      },
    ) => Promise<{ signed_id: string }>
  }
}

export interface RecipeStep {
  /** What the step does, shown while it runs: "Importing products". */
  title: string
  run(client: RecipeClient): Promise<void>
}

export interface RecipeProgress {
  step: RecipeStep
  /** 1-based position of the step. */
  number: number
  total: number
}

/** A step that failed, with the step it was. */
export class RecipeError extends Error {
  constructor(
    readonly step: RecipeStep,
    cause: unknown,
  ) {
    super(`${step.title} failed: ${cause instanceof Error ? cause.message : String(cause)}`)
    this.name = 'RecipeError'
    this.cause = cause
  }
}

/** Runs the steps in order and stops at the first that fails. */
export async function runRecipe(
  client: RecipeClient,
  steps: RecipeStep[],
  { onStep }: { onStep?: (progress: RecipeProgress) => void } = {},
): Promise<void> {
  for (const [index, step] of steps.entries()) {
    onStep?.({ step, number: index + 1, total: steps.length })
    try {
      await step.run(client)
    } catch (error) {
      throw new RecipeError(step, error)
    }
  }
}

/** Deploys a store file, with variables read from the store when it takes any. */
export function deployStep(
  title: string,
  yaml: string,
  variables?: (client: RecipeClient) => Promise<Variables>,
): RecipeStep {
  return {
    title,
    async run(client) {
      const { config } = parseConfig(yaml, variables ? await variables(client) : {})
      const report = await deployConfig(config, client)
      if (reportHasFailures(report)) throw new Error(renderReport(report))
    },
  }
}

interface Import extends LiveRecord {
  status: string
  failed_rows_count?: number
  processing_errors?: string | null
}

interface ImportRow extends LiveRecord {
  row_number?: number
  validation_errors?: string | null
}

export interface ImportOptions {
  /** The import type shorthand, e.g. `products`. */
  type: string
  csv: string
  filename: string
  /** Extra attributes of the import, e.g. the price list its rows go into. */
  attributes?: (client: RecipeClient) => Promise<Record<string, unknown>>
  /** How often the import is checked, and how long it may take. */
  pollMs?: number
  timeoutMs?: number
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

/**
 * Imports a CSV through the same pipeline a merchant's upload takes, and
 * waits for it: the next step usually needs the rows to be there.
 */
export function importStep(title: string, options: ImportOptions): RecipeStep {
  const { type, csv, filename, attributes, pollMs = 2000, timeoutMs = 20 * 60_000 } = options
  return {
    title,
    async run(client) {
      const upload = await client.files.upload(new Blob([csv], { type: 'text/csv' }), {
        visibility: 'private',
        filename,
        contentType: 'text/csv',
        // Small files: sent in the request itself, with no storage round-trip.
        method: 'multipart',
      })
      const created = await client.request<Import>('POST', '/imports', {
        body: {
          type,
          attachment_signed_id: upload.signed_id,
          ...(attributes ? await attributes(client) : {}),
        },
      })
      // The columns are the schema's own names, so the mapping assigned on
      // create is complete.
      await client.request('PATCH', `/imports/${created.id}/complete_mapping`, { body: {} })

      const deadline = Date.now() + timeoutMs
      let current = created
      while (!['completed', 'failed'].includes(current.status)) {
        if (Date.now() > deadline) throw new Error(`the ${type} import did not finish in time`)
        await sleep(pollMs)
        current = await client.request<Import>('GET', `/imports/${created.id}`)
      }
      if (current.status === 'failed') {
        throw new Error(current.processing_errors || `the ${type} import failed`)
      }
      if (current.failed_rows_count) {
        const failed = await client.request<{ data: ImportRow[] }>(
          'GET',
          `/imports/${created.id}/rows`,
          { params: { 'q[status_eq]': 'failed', limit: 5 } },
        )
        const reasons = failed.data
          .map((row) => `row ${row.row_number}: ${row.validation_errors}`)
          .join('; ')
        throw new Error(`${current.failed_rows_count} ${type} rows failed (${reasons})`)
      }
    },
  }
}
