import type { AttributeChange } from './types.js'

/**
 * A reference to a record the file declares but the live instance does not
 * hold yet. Resolved to an id at apply time, once the record is created.
 */
export class PendingRef {
  constructor(
    readonly section: string,
    readonly key: string,
  ) {}
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isPrimitive(value: unknown): boolean {
  return value === null || ['string', 'number', 'boolean'].includes(typeof value)
}

/**
 * Money and numeric attributes come back from the API as strings ("19.99")
 * and are written in the file as numbers; both compare as numbers.
 */
function normalize(value: unknown): unknown {
  if (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) {
    return Number(value)
  }
  if (value === undefined) return null
  return value
}

/** Structural equality with numeric strings and numbers unified. */
export function valuesEqual(desired: unknown, current: unknown): boolean {
  if (desired instanceof PendingRef) return false
  if (Array.isArray(desired) && Array.isArray(current)) {
    if (desired.length !== current.length) return false
    // A list of scalars is a set on the wire (ids, codes): order is not a change.
    if (desired.every(isPrimitive) && current.every(isPrimitive)) {
      const left = desired.map(normalize).map(String).sort()
      const right = current.map(normalize).map(String).sort()
      return left.every((item, index) => item === right[index])
    }
    return desired.every((item, index) => valuesEqual(item, current[index]))
  }
  if (isPlainObject(desired) && isPlainObject(current)) {
    return Object.keys(desired).every((key) => valuesEqual(desired[key], current[key]))
  }
  return normalize(desired) === normalize(current)
}

/**
 * Attributes of `desired` that differ from `current`. Only attributes the
 * file sets take part: the file never claims anything about the rest.
 */
export function diffAttributes(
  desired: Record<string, unknown>,
  current: Record<string, unknown>,
): AttributeChange[] {
  const changes: AttributeChange[] = []
  for (const [attribute, to] of Object.entries(desired)) {
    if (to === undefined) continue
    const from = current[attribute]
    if (!valuesEqual(to, from)) changes.push({ attribute, from: from ?? null, to })
  }
  return changes
}
