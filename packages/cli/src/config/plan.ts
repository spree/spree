import { RunContext } from './context.js'
import { diffAttributes } from './diff.js'
import { ConfigError } from './errors.js'
import type { SpreeConfig } from './schema.js'
import { ORDERED_SECTIONS, type Section, SOURCES } from './sections/index.js'
import type {
  ConfigClient,
  LiveRecord,
  Plan,
  PlanOperation,
  PlanOptions,
  SectionName,
  SectionPlan,
} from './types.js'

/** A plan operation with what apply needs: the request body it was planned from. */
export interface PlannedOperation extends PlanOperation {
  payload?: Record<string, unknown>
}

export interface PlannedSection extends SectionPlan {
  operations: PlannedOperation[]
}

export interface PlannedRun extends Plan {
  sections: PlannedSection[]
  ctx: RunContext
}

/** Sections the file declares, in dependency order. */
export function presentSections(config: SpreeConfig): SectionName[] {
  return ORDERED_SECTIONS.filter((section) => config[section.name] !== undefined).map(
    (section) => section.name,
  )
}

function operation(
  section: Section<never>,
  partial: Omit<PlannedOperation, 'section'>,
): PlannedOperation {
  return { section: section.name, ...partial }
}

async function planSingleton(
  section: Section<never>,
  ctx: RunContext,
): Promise<PlannedOperation[]> {
  const [entry] = section.entries(ctx.config)
  const live = await ctx.client.request<LiveRecord>('GET', section.path)
  const path = section.name
  const payload = await section.desired(entry, ctx, path)
  const changes = diffAttributes(payload, await section.current(live, ctx, entry))
  return [
    operation(section, {
      kind: changes.length ? 'update' : 'unchanged',
      key: section.name,
      path,
      changes,
      entry,
      live,
      payload,
    }),
  ]
}

async function planCollection(
  section: Section<never>,
  ctx: RunContext,
  prune: boolean,
): Promise<PlannedOperation[]> {
  const entries = section.entries(ctx.config)
  const keys = entries.map((entry) => section.entryKey(entry))
  const operations: PlannedOperation[] = []

  const seen = new Set<string>()
  for (const [index, key] of keys.entries()) {
    if (seen.has(key)) {
      operations.push(
        operation(section, {
          kind: 'error',
          key,
          path: `${section.name}[${index}]`,
          message: `${section.keyAttribute} "${key}" appears more than once in the file`,
        }),
      )
    }
    seen.add(key)
  }

  const live = await ctx.load(section.name, prune ? undefined : keys)

  for (const [index, entry] of entries.entries()) {
    const key = keys[index]
    const path = `${section.name}[${index}]`
    if (operations.some((existing) => existing.key === key && existing.kind === 'error')) continue
    const matches = live.byKey.get(key) ?? []
    if (matches.length > 1) {
      operations.push(
        operation(section, {
          kind: 'error',
          key,
          path,
          message: `${matches.length} live records share ${section.keyAttribute} "${key}"; rename them before deploying`,
        }),
      )
      continue
    }
    let payload: Record<string, unknown>
    try {
      payload = await section.desired(entry, ctx, path)
    } catch (error) {
      if (error instanceof ConfigError) {
        operations.push(operation(section, { kind: 'error', key, path, message: error.message }))
        continue
      }
      throw error
    }
    const match = matches[0]
    if (!match) {
      operations.push(operation(section, { kind: 'create', key, path, entry, payload }))
      continue
    }
    const changes = diffAttributes(payload, await section.current(match, ctx, entry))
    operations.push(
      operation(section, {
        kind: changes.length ? 'update' : 'unchanged',
        key,
        path,
        changes,
        entry,
        live: match,
        payload,
      }),
    )
  }

  if (live.complete) {
    for (const [key, records] of live.byKey) {
      if (seen.has(key)) continue
      for (const record of records) {
        operations.push(
          operation(section, {
            kind: prune ? 'delete' : 'unmanaged',
            key,
            path: section.name,
            live: record,
          }),
        )
      }
    }
  }

  return operations
}

/**
 * Reads the live store and classifies every entry of every present section
 * as create, update, unchanged or error, and live records absent from the
 * file as delete (pruned sections) or unmanaged (sections listed whole).
 * Nothing is written.
 */
export async function planConfig(
  config: SpreeConfig,
  client: ConfigClient,
  options: PlanOptions = {},
): Promise<PlannedRun> {
  const ctx = new RunContext(client, config, SOURCES)
  const prune = new Set(options.prune ?? [])
  const sections: PlannedSection[] = []

  for (const section of ORDERED_SECTIONS) {
    if (config[section.name] === undefined) continue
    const operations = section.singleton
      ? await planSingleton(section, ctx)
      : await planCollection(section, ctx, prune.has(section.name))
    sections.push({ section: section.name, operations })
  }

  return { sections, ctx }
}

export function planOperations(plan: Plan): PlanOperation[] {
  return plan.sections.flatMap((section) => section.operations)
}

export function planHasErrors(plan: Plan): boolean {
  return planOperations(plan).some((operation) => operation.kind === 'error')
}

export function planHasChanges(plan: Plan): boolean {
  return planOperations(plan).some((operation) =>
    ['create', 'update', 'delete'].includes(operation.kind),
  )
}

export function planHasDeletes(plan: Plan): boolean {
  return planOperations(plan).some((operation) => operation.kind === 'delete')
}
