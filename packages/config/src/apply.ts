import { inBatches } from './client.js'
import type { PlannedOperation, PlannedRun } from './plan.js'
import { type AnySection, SECTIONS } from './sections/index.js'
import type { ApplyReport, ApplyResult, LiveRecord } from './types.js'

/** Writes within a section that run at once. */
const CONCURRENCY = 4

interface ApiFailure {
  status?: number
  message?: string
  details?: Record<string, unknown>
}

/** Turns a thrown error into the failed result for an operation. */
function failure(operation: PlannedOperation, error: unknown): ApplyResult {
  const api = error as ApiFailure
  const message = error instanceof Error ? error.message : String(error)
  return {
    operation,
    status: 'failed',
    message: api?.status ? `HTTP ${api.status}: ${message}` : message,
    ...(api?.details ? { details: api.details } : {}),
  }
}

async function write(
  section: AnySection,
  operation: PlannedOperation,
  run: PlannedRun,
): Promise<ApplyResult> {
  const { ctx } = run
  try {
    const payload = ctx.materialize(operation.payload ?? {})
    const entry = operation.entry as never
    let live: LiveRecord
    if (operation.kind === 'create') {
      live = section.create
        ? await section.create(payload, entry, ctx)
        : await ctx.client.request<LiveRecord>('POST', section.path, { body: payload })
    } else {
      const current = operation.live as LiveRecord
      live = section.update
        ? await section.update(current, payload, entry, ctx)
        : await ctx.client.request<LiveRecord>('PATCH', `${section.path}/${current.id}`, {
            body: payload,
          })
    }
    ctx.register(section.name, operation.key, live)
    if (section.afterWrite) await section.afterWrite(entry, live, operation.changes ?? [], ctx)
    return { operation, status: 'applied' }
  } catch (error) {
    return failure(operation, error)
  }
}

async function remove(
  section: AnySection,
  operation: PlannedOperation,
  run: PlannedRun,
): Promise<ApplyResult> {
  const { ctx } = run
  try {
    const live = operation.live as LiveRecord
    if (section.remove) await section.remove(live, ctx)
    else await ctx.client.request('DELETE', `${section.path}/${live.id}`)
    return { operation, status: 'applied' }
  } catch (error) {
    return failure(operation, error)
  }
}

/**
 * Executes a plan: creates and updates section by section in dependency
 * order, deletes in reverse order afterwards. One failed entry is reported
 * and the rest of the run continues, so a single bad row never hides the
 * others.
 */
export async function applyPlan(run: PlannedRun): Promise<ApplyReport> {
  const results: ApplyResult[] = []

  for (const planned of run.sections) {
    const section = SECTIONS[planned.section]
    const writes = planned.operations.filter(
      (operation) => operation.kind === 'create' || operation.kind === 'update',
    )
    await inBatches(writes, section.sequential ? 1 : CONCURRENCY, async (operation) => {
      results.push(await write(section, operation, run))
    })
    // A plan error is a failed deploy of that entry, not a quiet skip: a
    // dangling reference must make a scripted run fail the way a 422 does.
    for (const operation of planned.operations) {
      if (operation.kind === 'error')
        results.push({ operation, status: 'failed', message: operation.message })
    }
  }

  for (const planned of [...run.sections].reverse()) {
    const section = SECTIONS[planned.section]
    const deletes = planned.operations.filter((operation) => operation.kind === 'delete')
    await inBatches(deletes, CONCURRENCY, async (operation) => {
      results.push(await remove(section, operation, run))
    })
  }

  return { results }
}

export function reportHasFailures(report: ApplyReport): boolean {
  return report.results.some((result) => result.status === 'failed')
}
