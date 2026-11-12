import { describe, expect, it } from 'vitest'
import { isWebhookEventPattern, WEBHOOK_SUBSCRIPTION_MAX_LENGTH } from '../src'

describe('isWebhookEventPattern', () => {
  it('accepts event names, segment wildcards and the catch-all', () => {
    for (const value of [
      '*',
      'order.placed',
      'order.*',
      '*.created',
      'order.line_item.*',
      'my_app.Thing-done',
    ]) {
      expect(isWebhookEventPattern(value), value).toBe(true)
    }
  })

  it('refuses regexp syntax, partial-segment wildcards, empty segments and non-ASCII letters', () => {
    for (const value of [
      'order.(placed|canceled)',
      'order.p*',
      'order..placed',
      '.placed',
      'order placed',
      'order.placed$',
      'order.place\u017f',
      '',
      'a'.repeat(WEBHOOK_SUBSCRIPTION_MAX_LENGTH + 1),
      42,
      null,
    ]) {
      expect(isWebhookEventPattern(value), String(value)).toBe(false)
    }
  })
})
