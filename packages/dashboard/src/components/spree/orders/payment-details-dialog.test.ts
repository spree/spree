import { describe, expect, it } from 'vitest'
import { addressCheck, securityCodeCheck } from './payment-details-dialog'

describe('securityCodeCheck', () => {
  it.each([
    [null, false, 'not_checked'],
    ['M', false, 'passed'],
    ['N', true, 'failed'],
    ['D', true, 'failed'],
    ['I', true, 'failed'],
    ['P', true, 'unavailable'],
    ['S', true, 'unavailable'],
    ['U', true, 'unavailable'],
    ['X', true, 'unavailable'],
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
    ['E', true, 'unavailable'],
    ['G', true, 'unavailable'],
    ['I', true, 'unavailable'],
    ['R', true, 'unavailable'],
    ['S', true, 'unavailable'],
    ['U', true, 'unavailable'],
  ] as const)('reads %s (risky: %s) as %s', (code, risky, outcome) => {
    expect(addressCheck({ avs_response: code, avs_risky: risky })).toBe(outcome)
  })
})
