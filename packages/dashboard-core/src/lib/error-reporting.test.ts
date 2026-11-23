import { notFound, redirect } from '@tanstack/react-router'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { addErrorReporter, reportCaughtError } from './error-reporting'

describe('reportCaughtError', () => {
  const removers: Array<() => void> = []
  afterEach(() => {
    for (const remove of removers.splice(0)) remove()
  })

  it('hands errors to every reporter, even when one throws', () => {
    const first = vi.fn(() => {
      throw new Error('reporter down')
    })
    const second = vi.fn()
    removers.push(addErrorReporter('first', first), addErrorReporter('second', second))
    vi.spyOn(console, 'error').mockImplementation(() => {})

    const error = new Error('boom')
    reportCaughtError(error)

    expect(first).toHaveBeenCalledWith(error, undefined)
    expect(second).toHaveBeenCalledWith(error, undefined)
  })

  it('skips the router’s control flow', () => {
    const reporter = vi.fn()
    removers.push(addErrorReporter('reporter', reporter))

    reportCaughtError(notFound())
    reportCaughtError(redirect({ to: '/' }))

    expect(reporter).not.toHaveBeenCalled()
  })

  it('stops reporting to a removed reporter', () => {
    const reporter = vi.fn()
    addErrorReporter('reporter', reporter)()

    reportCaughtError(new Error('boom'))

    expect(reporter).not.toHaveBeenCalled()
  })

  it('refuses a second reporter under the same id', () => {
    removers.push(addErrorReporter('tracker', vi.fn()))

    expect(() => addErrorReporter('tracker', vi.fn())).toThrow(/already registered/)
  })
})
