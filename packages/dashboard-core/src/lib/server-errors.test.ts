import { SpreeError } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { offscreenSummaryOf, serverErrorStateFrom, withoutField } from './server-errors'

function rejected(details: Record<string, Array<{ code: string; message: string }>>) {
  return new SpreeError(
    { error: { code: 'validation_error', message: 'The save was refused', details } },
    422,
  )
}

describe('server error state', () => {
  it('shows the summary while a named field has no place on screen', () => {
    const state = serverErrorStateFrom(
      rejected({ base: [{ code: 'invalid', message: 'is invalid' }] }),
    )

    expect(state && offscreenSummaryOf(state, ['name'])).toBeTruthy()
  })

  it('leaves the summary out while every named field shows its own message', () => {
    const state = serverErrorStateFrom(
      rejected({ name: [{ code: 'taken', message: 'has already been taken' }] }),
    )

    expect(state && offscreenSummaryOf(state, ['name'])).toBeUndefined()
  })

  // A supplier's state error, then a country with no states: the state input
  // goes, and so must the summary that would otherwise speak for it.
  it('drops a cleared field from the summary as well as its message', () => {
    const state = serverErrorStateFrom(
      rejected({ state_code: [{ code: 'invalid', message: 'is invalid' }] }),
    )
    if (!state) throw new Error('expected an API error')

    const cleared = withoutField(state, 'state_code')

    expect(cleared.errors.state_code).toBeUndefined()
    expect(offscreenSummaryOf(cleared, ['name'])).toBeUndefined()
  })

  it('keeps the same state when the changed field had nothing to clear', () => {
    const state = serverErrorStateFrom(
      rejected({ name: [{ code: 'taken', message: 'has already been taken' }] }),
    )
    if (!state) throw new Error('expected an API error')

    expect(withoutField(state, 'email')).toBe(state)
  })
})
