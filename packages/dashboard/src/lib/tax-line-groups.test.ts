import { describe, expect, it } from 'vitest'
import {
  type GroupableTaxLine,
  groupTaxLines,
  showsTaxabilityReason,
  taxLineExemption,
} from './tax-line-groups'

function taxLine(overrides: Partial<GroupableTaxLine> = {}): GroupableTaxLine {
  return {
    label: 'California Sales Tax 7.25%',
    amount: '8.70',
    taxability_reason: 'standard_rated',
    country_code: 'US',
    state_code: 'CA',
    data: {},
    ...overrides,
  }
}

describe('taxLineExemption', () => {
  it('reads the certificate snapshot from the provider payload', () => {
    expect(
      taxLineExemption(
        taxLine({
          data: {
            exemption: { reason_code: 'resale', certificate_number: 'CA-SR-100-284617' },
          },
        }),
      ),
    ).toEqual({ reason_code: 'resale', certificate_number: 'CA-SR-100-284617' })
  })

  it('returns null when the payload has no exemption', () => {
    expect(taxLineExemption(taxLine())).toBeNull()
    expect(taxLineExemption(taxLine({ data: null }))).toBeNull()
    expect(taxLineExemption(taxLine({ data: { exemption: 'resale' } }))).toBeNull()
  })
})

describe('groupTaxLines', () => {
  it('sums lines that share a label and the same treatment', () => {
    const groups = groupTaxLines([taxLine({ amount: '4.35' }), taxLine({ amount: '4.35' })])

    expect(groups).toHaveLength(1)
    expect(groups[0]?.amount).toBeCloseTo(8.7)
    expect(groups[0]?.taxabilityReason).toBe('standard_rated')
  })

  it('keeps an exempt row apart from a charged row with the same label', () => {
    const groups = groupTaxLines([
      taxLine({ amount: '8.70' }),
      taxLine({
        amount: '0.00',
        taxability_reason: 'customer_exempt',
        data: { exemption: { reason_code: 'resale', certificate_number: 'CA-SR-100-284617' } },
      }),
    ])

    expect(groups.map((group) => [group.taxabilityReason, group.amount])).toEqual([
      ['standard_rated', 8.7],
      ['customer_exempt', 0],
    ])
    expect(groups[1]?.exemption).toEqual({
      reason_code: 'resale',
      certificate_number: 'CA-SR-100-284617',
    })
  })

  it('keeps two certificates on the same rate as separate rows', () => {
    const groups = groupTaxLines([
      taxLine({
        amount: '0.00',
        taxability_reason: 'customer_exempt',
        data: { exemption: { reason_code: 'resale', certificate_number: 'CA-1' } },
      }),
      taxLine({
        amount: '0.00',
        taxability_reason: 'customer_exempt',
        data: { exemption: { reason_code: 'government', certificate_number: 'CA-2' } },
      }),
    ])

    expect(groups).toHaveLength(2)
    expect(groups[0]?.exemption?.certificate_number).toBe('CA-1')
    expect(groups[1]?.exemption?.certificate_number).toBe('CA-2')
  })
})

describe('showsTaxabilityReason', () => {
  it('hides the badge on a standard charged rate', () => {
    const [group] = groupTaxLines([taxLine()])
    expect(showsTaxabilityReason(group!)).toBe(false)
  })

  it('shows the badge for an exemption or a zero rate', () => {
    const [exempt] = groupTaxLines([
      taxLine({ amount: '0.00', taxability_reason: 'customer_exempt' }),
    ])
    const [zeroRated] = groupTaxLines([
      taxLine({ amount: '0.00', taxability_reason: 'zero_rated' }),
    ])

    expect(showsTaxabilityReason(exempt!)).toBe(true)
    expect(showsTaxabilityReason(zeroRated!)).toBe(true)
  })
})
