/**
 * How tax rows are shown on an order: one rate charged on many lines
 * collapses to a single amount, but a different treatment (exempt vs
 * zero-rated vs standard) stays its own row so those cases do not look
 * identical.
 */

/** The tax-line fields the grouping reads. */
export interface GroupableTaxLine {
  label: string
  amount: string
  taxability_reason?: string | null
  country_code?: string | null
  state_code?: string | null
  data?: Record<string, unknown> | null
}

/** The exemption snapshot a tax provider stamps onto a line. */
export interface TaxLineExemption {
  reason_code?: string
  certificate_number?: string
}

/** One grouped tax row for the Taxes card. */
export interface TaxLineGroup {
  key: string
  label: string
  amount: number
  taxabilityReason: string | null
  exemption: TaxLineExemption | null
  countryCode: string | null
  stateCode: string | null
}

/**
 * The exemption claim the provider stored on this line, if any.
 *
 * @param row - A tax line as returned by the Admin API
 * @returns The certificate snapshot, or null when none was recorded
 */
export function taxLineExemption(row: GroupableTaxLine): TaxLineExemption | null {
  const raw = row.data?.exemption
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null

  const record = raw as Record<string, unknown>
  const reasonCode = typeof record.reason_code === 'string' ? record.reason_code : undefined
  const certificateNumber =
    typeof record.certificate_number === 'string' ? record.certificate_number : undefined
  if (!reasonCode && !certificateNumber) return null

  return { reason_code: reasonCode, certificate_number: certificateNumber }
}

/**
 * Groups tax lines that share a label *and* the same treatment. Two
 * California rates that one line paid and another was exempt from must
 * not collapse into a single $0.00 row.
 *
 * @param rows - Tax lines for one order
 * @returns Display groups in first-seen order
 */
export function groupTaxLines(rows: GroupableTaxLine[]): TaxLineGroup[] {
  const groups = new Map<string, TaxLineGroup>()

  for (const row of rows) {
    const exemption = taxLineExemption(row)
    const key = [
      row.label,
      row.taxability_reason ?? '',
      exemption?.certificate_number ?? '',
      exemption?.reason_code ?? '',
    ].join('\0')
    const parsed = Number.parseFloat(row.amount)
    const amount = Number.isFinite(parsed) ? parsed : 0
    const existing = groups.get(key)

    if (existing) {
      existing.amount += amount
      continue
    }

    groups.set(key, {
      key,
      label: row.label,
      amount,
      taxabilityReason: row.taxability_reason ?? null,
      exemption,
      countryCode: row.country_code ?? null,
      stateCode: row.state_code ?? null,
    })
  }

  return [...groups.values()]
}

/**
 * Whether the row's treatment is something an agent must see — a
 * standard positive charge is already explained by the rate label.
 *
 * @param group - A grouped tax row
 * @returns True when a reason badge should render
 */
export function showsTaxabilityReason(group: TaxLineGroup): boolean {
  return Boolean(group.taxabilityReason && group.taxabilityReason !== 'standard_rated')
}
