/**
 * One-line preview of a calculator's configuration — "Flat Rate · $5.00",
 * "Percent on line item · 10%", etc. Used for promotion-action rows
 * today; intended as the shared row-summary for any calculator-backed
 * model (delivery methods, tax rates, …).
 *
 * The expected payload mirrors the admin API's calculator embed: a
 * `{ label, preferences, schema }` triple, `schema` being the JSON Schema of
 * the calculator's preferences. The component is
 * tolerant of partial input — missing schema or preferences just fall
 * back to the label alone.
 *
 * Lives on the frontend (rather than as a server-rendered string) so
 * draft edits update the row immediately, before any save.
 */
export interface CalculatorPayload {
  /**
   * Display name for the calculator, already localized by the caller — this
   * package is headless and does not resolve translations itself. Optional;
   * if missing the type is demodulized.
   */
  label?: string | null
  /** STI class name (e.g. "Spree::Calculator::FlatRate"). Used as a label fallback. */
  type?: string | null
  preferences?: Record<string, unknown> | null
  schema?: { properties?: Record<string, CalculatorPropertySchema> } | null
}

/** The part of a preference's JSON Schema the summary reads. */
interface CalculatorPropertySchema {
  type?: string | string[]
  format?: string
  pattern?: string
}

interface CalculatorSummaryProps {
  calculator: CalculatorPayload | null | undefined
  /**
   * What to show when `calculator` is missing or empty. Use this to
   * differentiate "no calculator picked" from "calculator with no
   * preferences yet." Defaults to nothing (returns null).
   */
  fallback?: React.ReactNode
  className?: string
}

export function CalculatorSummary({
  calculator,
  fallback = null,
  className,
}: CalculatorSummaryProps) {
  const text = formatCalculatorSummary(calculator)
  if (!text) return <>{fallback}</>
  return <span className={className}>{text}</span>
}

/**
 * Pure formatter — exported for callers that want to embed the string
 * inside a larger sentence (e.g. "Free shipping · {summary}") or use
 * it in a non-React context.
 */
export function formatCalculatorSummary(
  calculator: CalculatorPayload | null | undefined,
): string | null {
  if (!calculator) return null

  const label =
    calculator.label?.trim() ||
    (calculator.type ? (calculator.type.split('::').pop() ?? calculator.type) : '')

  const properties = Object.entries(calculator.schema?.properties ?? {})
  const prefs = calculator.preferences

  if (!properties.length || !prefs) return label || null

  const currency = (typeof prefs.currency === 'string' && prefs.currency) || 'USD'
  const details = properties
    .map(([key, property]) => formatField(key, property, prefs[key], currency))
    .filter((s): s is string => s !== null)
    .join(', ')

  if (!details) return label || null
  return label ? `${label} · ${details}` : details
}

/**
 * Formats one preference value from its schema.
 *
 * - money → currency-formatted.
 * - `*_percent` values → `N%`.
 * - currencies → omitted (folded into the money formatting).
 * - booleans → humanized key when true; skipped when false.
 * - lists (tiers) → their length; objects → omitted.
 * - everything else → `key: value`.
 */
function formatField(
  key: string,
  property: CalculatorPropertySchema,
  value: unknown,
  currency: string,
): string | null {
  if (value === null || value === undefined || value === '') return null
  if (property.format === 'currency') return null
  if (property.format === 'money') return formatMoney(value, currency)
  if (/(?:^|_)percent$/.test(key)) return `${value}%`

  const type = (Array.isArray(property.type) ? property.type : [property.type]).find(
    (t) => t !== 'null',
  )
  if (type === 'boolean') return value ? humanize(key) : null
  if (type === 'array') {
    return Array.isArray(value) && value.length ? `${humanize(key)}: ${value.length}` : null
  }
  if (type === 'object') return null
  return `${humanize(key)}: ${value}`
}

function formatMoney(value: unknown, currency: string): string {
  const amount = String(value)
  if (!/^-?\d+(\.\d+)?$/.test(amount)) return amount
  try {
    // `Intl` reads a numeric string exactly; its ES2022 typings only list numbers.
    return new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(
      amount as unknown as number,
    )
  } catch {
    return `${amount} ${currency}`
  }
}

function humanize(key: string): string {
  const spaced = key.replace(/_/g, ' ').trim()
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}
