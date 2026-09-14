/**
 * Shared vocabulary of the configurator engine: the client it talks through,
 * the plan it produces and the report an apply returns.
 */

import { configSchema, type SpreeConfig } from './schema.js'

/** Every section the file may carry — the schema's keys, less the version. */
export type SectionName = Exclude<keyof SpreeConfig, 'version'>

export const SECTION_NAMES = Object.keys(configSchema.shape).filter(
  (key) => key !== 'version',
) as SectionName[]

export interface RequestOptions {
  params?: Record<string, string | number | boolean | (string | number)[] | undefined>
  body?: unknown
}

/**
 * The slice of `@spree/admin-sdk`'s client the engine needs. Structural, so
 * tests can hand in a stub and the dashboard e2e setup can hand in a real
 * `createAdminClient(...)`.
 */
export interface ConfigClient {
  request: <T>(method: string, path: string, options?: RequestOptions) => Promise<T>
}

/**
 * A record as the Admin API returns it. Sections narrow this to the SDK's
 * generated type for their resource (`Section<Entry, Channel>`), so a
 * misspelled attribute in a section is a compile error rather than a silent
 * `undefined`; the index signature carries the expanded associations the
 * generated types mark optional.
 */
export interface LiveRecord {
  id: string
  [attribute: string]: unknown
}

export type OperationKind = 'create' | 'update' | 'unchanged' | 'delete' | 'unmanaged' | 'error'

export interface AttributeChange {
  attribute: string
  from: unknown
  to: unknown
}

export interface PlanOperation {
  section: SectionName
  kind: OperationKind
  /** Natural key of the record, or `store` for the singleton. */
  key: string
  /** Where the entry sits in the file, e.g. `products[2]` — what an error is reported against. */
  path: string
  changes?: AttributeChange[]
  /** For `error`: what is wrong. */
  message?: string
  /** For `create`/`update`: the file entry the payload came from. */
  entry?: unknown
  /** For `update`/`delete`/`unchanged`: the live record. */
  live?: LiveRecord
}

export interface SectionPlan {
  section: SectionName
  operations: PlanOperation[]
}

export interface Plan {
  sections: SectionPlan[]
}

export type ApplyStatus = 'applied' | 'failed'

export interface ApplyResult {
  operation: PlanOperation
  status: ApplyStatus
  message?: string
  /** The API's own validation details for a 422, keyed by attribute. */
  details?: Record<string, unknown>
}

export interface ApplyReport {
  results: ApplyResult[]
}

export interface PlanOptions {
  /** Sections whose live records absent from the file become deletes. */
  prune?: SectionName[]
}
