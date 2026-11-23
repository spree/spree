import { SpreeError } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { readServerErrors } from './use-server-errors'

describe('readServerErrors', () => {
  it('puts a field message on its field and keeps the summary', () => {
    const error = new SpreeError(
      {
        error: {
          code: 'validation_error',
          message: 'Name has already been taken',
          details: { name: [{ code: 'taken', message: 'has already been taken' }] },
        },
      },
      422,
    )

    const errors = readServerErrors(error)

    expect(errors?.name).toBeTruthy()
    expect(errors?.root).toBeTruthy()
  })

  it('keeps a refusal with no field as the summary alone', () => {
    const error = new SpreeError(
      { error: { code: 'processing_error', message: 'Only a draft can be edited' } },
      422,
    )

    expect(readServerErrors(error)).toEqual({ root: 'Only a draft can be edited' })
  })

  it('leaves an error that is not from the API to the caller', () => {
    expect(readServerErrors(new TypeError('Failed to fetch'))).toBeNull()
  })
})
