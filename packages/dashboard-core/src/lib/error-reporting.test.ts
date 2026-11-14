import { notFound, redirect } from '@tanstack/react-router'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { addErrorReporter, reportError } from './error-reporting'

describe('reportError', () => {
  const removers: Array<() => void> = []
  afterEach(() => {
    for (const remove of removers.splice(0)) remove()
  })

  it('hands errors to every reporter, even when one throws', () => {
    const first = vi.fn(() => {
      throw new Error('reporter down')
    })
    const second = vi.fn()
    removers.push(addErrorReporter(first), addErrorReporter(second))
    vi.spyOn(console, 'error').mockImplementation(() => {})

    const error = new Error('boom')
    reportError(error)

    expect(first).toHaveBeenCalledWith(error, undefined)
    expect(second).toHaveBeenCalledWith(error, undefined)
  })

  it('skips the router’s control flow', () => {
    const reporter = vi.fn()
    removers.push(addErrorReporter(reporter))

    reportError(notFound())
    reportError(redirect({ to: '/' }))

    expect(reporter).not.toHaveBeenCalled()
  })

  it('stops reporting to a removed reporter', () => {
    const reporter = vi.fn()
    addErrorReporter(reporter)()

    reportError(new Error('boom'))

    expect(reporter).not.toHaveBeenCalled()
  })
})
