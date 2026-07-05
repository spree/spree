/**
 * One-line preview of a calculator's configuration — "Flat Rate · $5.00",
 * "Percent on line item · 10%", etc. Used for promotion-action rows
 * today; intended as the shared row-summary for any calculator-backed
 * model (delivery methods, tax rates, …).
 *
 * The expected payload mirrors the admin API's calculator embed: a
 * `{ label, preferences, preference_schema }` triple. The component is
 * tolerant of partial input — missing schema or preferences just fall
 * back to the label alone.
 *
 * Lives on the frontend (rather than as a server-rendered string) so
 * draft edits update the row immediately, before any save.
 */
export interface CalculatorPayload {
  /** Human-readable name (e.g. "Flat Rate"). Optional; if missing the type is demodulized. */
  label?: string | null
  /** STI class name (e.g. "Spree::Calculator::FlatRate"). Used as a label fallback. */
  type?: string | null
  preferences?: Record<string, unknown> | null
  preference_schema?: ReadonlyArray<{ key: string; type: string }> | null
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

  const schema = calculator.preference_schema
  const prefs = calculator.preferences

  if (!schema?.length || !prefs) return label || null

  const currency = (typeof prefs.currency === 'string' && prefs.currency) || 'USD'
  const details = schema
    .map((field) => formatField(field, prefs[field.key], currency))
    .filter((s): s is string => s !== null)
    .join(', ')

  if (!details) return label || null
  return label ? `${label} · ${details}` : details
}

/**
 * Formats one preference value by naming convention. Calculators don't
 * carry richer field metadata (no `display_format`, no `unit`), so we
 * fall back to key-name heuristics that match the Ruby preference
 * declarations in `Spree::Calculator::*`.
 *
 * - `amount` / `*_amount` decimals → currency-formatted.
 * - `*_percent` decimals → `N%`.
 * - `currency` strings → omitted (folded into the money formatting).
 * - booleans → humanized key when true; skipped when false.
 * - everything else → `key: value`.
 */
function formatField(
  field: { key: string; type: string },
  value: unknown,
  currency: string,
): string | null {
  if (value === null || value === undefined || value === '') return null
  if (field.key === 'currency') return null

  if (field.type === 'decimal') {
    if (/(?:^|_)percent$/.test(field.key)) return `${value}%`
    if (field.key === 'amount' || field.key.endsWith('_amount')) {
      return formatMoney(value, currency)
    }
    return `${humanize(field.key)}: ${value}`
  }
  if (field.type === 'boolean') {
    return value ? humanize(field.key) : null
  }
  return `${humanize(field.key)}: ${value}`
}

function formatMoney(value: unknown, currency: string): string {
  const n = typeof value === 'number' ? value : Number(value)
  if (Number.isNaN(n)) return String(value)
  try {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(n)
  } catch {
    return `${n} ${currency}`
  }
}

function humanize(key: string): string {
  const spaced = key.replace(/_/g, ' ').trim()
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}
