/**
 * A metric value as a number, for plotting, bar widths and trend arrows only. Money, ratios
 * and growth arrive as decimal strings; nothing derived from this number is
 * sent anywhere or shown as a figure.
 */
export function metricNumberForChart(value: number | string | null | undefined): number {
  if (value === null || value === undefined || value === '') return 0
  const parsed = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(parsed) ? parsed : 0
}

/**
 * Formats a metric figure in the admin's locale. A decimal string goes to
 * `Intl` as it is, which reads it exactly; its ES2022 typings only list numbers.
 */
export function formatMetricNumber(
  value: number | string,
  locale: string,
  options?: Intl.NumberFormatOptions,
): string {
  return new Intl.NumberFormat(locale, options).format(value as number)
}
