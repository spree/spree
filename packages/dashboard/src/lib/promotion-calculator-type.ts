/**
 * Resolves a draft calculator `type` against the catalog returned by
 * `GET /promotion_actions/calculators`. The promotion action payload uses
 * api shorthand (`flat_rate`) while older catalog responses used the full
 * Ruby class name (`Spree::Calculator::FlatRate`).
 */
export function resolveCalculatorType(
  calculators: ReadonlyArray<{ type: string }>,
  type: string,
): string | undefined {
  if (!type) return undefined

  const normalized = normalizeCalculatorType(type)

  return calculators.find((calculator) => {
    const catalogType = calculator.type
    return (
      catalogType === type ||
      catalogType === normalized ||
      normalizeCalculatorType(catalogType) === normalized
    )
  })?.type
}

/** Mirrors `Spree::Base.api_type`: demodulize + underscore. */
export function normalizeCalculatorType(type: string): string {
  if (!type.includes('::')) return type

  const leaf = type.split('::').pop() ?? type
  return leaf
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
    .toLowerCase()
}
