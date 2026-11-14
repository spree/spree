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
 * and are written in the file as numbers. Only that pairing is bridged: two
 * strings compare as strings, so a postcode "02134" never equals "2134".
 */
function scalarsEqual(desired: unknown, current: unknown): boolean {
  const left = desired === undefined ? null : desired
  const right = current === undefined ? null : current
  if (typeof left === 'number' && typeof right === 'string') return numericString(right) === left
  if (typeof left === 'string' && typeof right === 'number') return numericString(left) === right
  return left === right
}

/** The number a string denotes, or null when it does not denote one. */
export function numericString(value: string): number | null {
  return /^-?\d+(\.\d+)?$/.test(value.trim()) ? Number(value) : null
}

function scalarKey(value: unknown): string {
  return typeof value === 'number' ? String(value) : JSON.stringify(value ?? null)
}

/** Structural equality with numeric strings and numbers unified. */
export function valuesEqual(desired: unknown, current: unknown): boolean {
  if (desired instanceof PendingRef) return false
  if (Array.isArray(desired) && Array.isArray(current)) {
    if (desired.length !== current.length) return false
    // A list of scalars is a set on the wire (ids, codes): order is not a change.
    if (desired.every(isPrimitive) && current.every(isPrimitive)) {
      const left = desired.map(scalarKey).sort()
      const right = current.map(scalarKey).sort()
      return left.every((item, index) => item === right[index])
    }
    return desired.every((item, index) => valuesEqual(item, current[index]))
  }
  if (isPlainObject(desired) && isPlainObject(current)) {
    return Object.keys(desired).every((key) => valuesEqual(desired[key], current[key]))
  }
  return scalarsEqual(desired, current)
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
