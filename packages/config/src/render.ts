import pc from 'picocolors'
import { PendingRef } from './diff.js'
import type { PlannedOperation, PlannedRun } from './plan.js'
import type { ApplyReport, AttributeChange, OperationKind, Plan, PlanOperation } from './types.js'

const MARK: Record<OperationKind, string> = {
  create: '+',
  update: '~',
  delete: '-',
  unchanged: '=',
  unmanaged: '?',
  error: '!',
}

const COLOR: Record<OperationKind, (text: string) => string> = {
  create: pc.green,
  update: pc.yellow,
  delete: pc.red,
  unchanged: pc.dim,
  unmanaged: pc.dim,
  error: pc.red,
}

function show(value: unknown): string {
  if (value === null || value === undefined) return pc.dim('null')
  if (value instanceof PendingRef) {
    return `${value.section}/${value.key} ${pc.dim('(created by this run)')}`
  }
  return JSON.stringify(value)
}

function renderChange(change: AttributeChange): string {
  return `      ${change.attribute}: ${show(change.from)} ${pc.dim('->')} ${show(change.to)}`
}

export interface RenderOptions {
  /** Print unchanged and unmanaged records too. */
  verbose?: boolean
}

/** The plan as a human-readable diff, grouped by section. */
export function renderPlan(plan: Plan, options: RenderOptions = {}): string {
  const lines: string[] = []
  for (const section of plan.sections) {
    const shown = section.operations.filter(
      (operation) => options.verbose || !['unchanged', 'unmanaged'].includes(operation.kind),
    )
    const unchanged = section.operations.filter(
      (operation) => operation.kind === 'unchanged',
    ).length
    const unmanaged = section.operations.filter(
      (operation) => operation.kind === 'unmanaged',
    ).length
    lines.push(pc.bold(section.section))
    for (const operation of shown) {
      const color = COLOR[operation.kind]
      const suffix = operation.kind === 'error' ? `: ${operation.message}` : ''
      lines.push(
        `  ${color(`${MARK[operation.kind]} ${operation.key}`)} ${pc.dim(`(${operation.kind})`)}${suffix}`,
      )
      if (operation.kind === 'update')
        for (const change of operation.changes ?? []) lines.push(renderChange(change))
    }
    const notes: string[] = []
    if (unchanged && !options.verbose) notes.push(`${unchanged} unchanged`)
    if (unmanaged && !options.verbose) notes.push(`${unmanaged} not managed by the file`)
    if (notes.length) lines.push(`  ${pc.dim(notes.join(', '))}`)
  }
  lines.push('')
  lines.push(summaryLine(plan))
  return lines.join('\n')
}

export function countByKind(plan: Plan): Record<OperationKind, number> {
  const counts: Record<OperationKind, number> = {
    create: 0,
    update: 0,
    delete: 0,
    unchanged: 0,
    unmanaged: 0,
    error: 0,
  }
  for (const section of plan.sections)
    for (const operation of section.operations) counts[operation.kind] += 1
  return counts
}

export function summaryLine(plan: Plan): string {
  const counts = countByKind(plan)
  const parts = [
    pc.green(`${counts.create} to create`),
    pc.yellow(`${counts.update} to update`),
    pc.red(`${counts.delete} to delete`),
    pc.dim(`${counts.unchanged} unchanged`),
  ]
  if (counts.error) parts.push(pc.red(`${counts.error} error${counts.error === 1 ? '' : 's'}`))
  return parts.join(', ')
}

/** The plan without live records and payloads, for `--format json`. */
export function planToJson(plan: Plan | PlannedRun): {
  sections: { section: string; operations: Omit<PlanOperation, 'live' | 'entry'>[] }[]
} {
  return {
    sections: plan.sections.map((section) => ({
      section: section.section,
      operations: section.operations.map((operation) => {
        const {
          live: _live,
          entry: _entry,
          payload: _payload,
          ...rest
        } = operation as PlannedOperation
        return rest
      }),
    })),
  }
}

/** Per-section outcome of an apply, one line per failure. */
export function renderReport(report: ApplyReport): string {
  const lines: string[] = []
  const bySection = new Map<string, { applied: number; failed: number }>()
  for (const result of report.results) {
    const counts = bySection.get(result.operation.section) ?? { applied: 0, failed: 0 }
    counts[result.status] += 1
    bySection.set(result.operation.section, counts)
    if (result.status === 'failed') {
      lines.push(
        `${pc.red('✗')} ${result.operation.path} ${pc.dim(`(${result.operation.key})`)}: ${result.message}`,
      )
      for (const [attribute, messages] of Object.entries(result.details ?? {})) {
        const text = Array.isArray(messages)
          ? messages
              .map((message) =>
                typeof message === 'object' && message && 'message' in message
                  ? String((message as { message: unknown }).message)
                  : String(message),
              )
              .join('; ')
          : JSON.stringify(messages)
        lines.push(`    ${attribute}: ${text}`)
      }
    }
  }
  for (const [section, counts] of bySection) {
    const parts = [pc.green(`${counts.applied} applied`)]
    if (counts.failed) parts.push(pc.red(`${counts.failed} failed`))
    lines.push(`${pc.bold(section)}: ${parts.join(', ')}`)
  }
  if (report.results.length === 0) lines.push(pc.dim('Nothing to apply.'))
  return lines.join('\n')
}
