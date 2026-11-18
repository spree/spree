import { describe, expect, it } from 'vitest'
import { addressCheck, riskyCardChecks, securityCodeCheck } from './payment-details-dialog'

describe('securityCodeCheck', () => {
  it.each([
    [null, false, 'not_checked'],
    ['M', false, 'passed'],
    ['N', true, 'failed'],
    ['D', true, 'failed'],
    ['I', true, 'failed'],
    ['P', true, 'unavailable'],
    ['S', true, 'failed'],
    ['U', true, 'unavailable'],
    ['X', true, 'unavailable'],
    ['x ', true, 'unavailable'],
    ['', true, 'failed'],
    [null, true, 'failed'],
  ] as const)('reads %s (risky: %s) as %s', (code, risky, outcome) => {
    expect(securityCodeCheck({ cvv_response_code: code, cvv_risky: risky })).toBe(outcome)
  })
})

describe('addressCheck', () => {
  it.each([
    [null, false, 'not_checked'],
    ['Y', false, 'passed'],
    ['N', true, 'failed'],
    ['A', true, 'failed'],
    ['Z', true, 'failed'],
    ['C', true, 'failed'],
    ['W', true, 'failed'],
    ['E', true, 'unavailable'],
    ['G', true, 'unavailable'],
    ['I', true, 'unavailable'],
    ['P', true, 'unavailable'],
    ['R', true, 'unavailable'],
    ['S', true, 'unavailable'],
    ['U', true, 'unavailable'],
    ['u', true, 'unavailable'],
    ['', true, 'failed'],
  ] as const)('reads %s (risky: %s) as %s', (code, risky, outcome) => {
    expect(addressCheck({ avs_response: code, avs_risky: risky })).toBe(outcome)
  })
})

describe('riskyCardChecks', () => {
  const payment = {
    avs_response: 'Y',
    avs_risky: false,
    cvv_response_code: 'M',
    cvv_risky: false,
  }

  it('is null when neither check is risky', () => {
    expect(riskyCardChecks(payment)).toBeNull()
  })

  it('is unavailable when the only risky check was not run', () => {
    expect(riskyCardChecks({ ...payment, cvv_response_code: 'P', cvv_risky: true })).toBe(
      'unavailable',
    )
  })

  it('is failed when a risky check has a blank code', () => {
    expect(riskyCardChecks({ ...payment, cvv_response_code: '', cvv_risky: true })).toBe('failed')
  })

  it('is failed when either check failed, even if the other was not run', () => {
    expect(
      riskyCardChecks({
        avs_response: 'U',
        avs_risky: true,
        cvv_response_code: 'N',
        cvv_risky: true,
      }),
    ).toBe('failed')
  })
})
