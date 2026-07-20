import { describe, expect, it } from 'vitest'
import { createClient } from '../src'
import { createTestClient, TEST_API_KEY, TEST_BASE_URL } from './helpers'

describe('channel', () => {
  it('gets the default channel with resolved posture', async () => {
    const client = createTestClient()

    const channel = await client.channel.get()

    expect(channel.code).toBe('online')
    expect(channel.default).toBe(true)
    expect(channel.storefront_access).toBe('public')
    expect(channel.guest_checkout).toBe(true)
  })

  it('resolves the configured channel via the X-Spree-Channel header', async () => {
    const client = createClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
      channel: 'wholesale',
    })

    const channel = await client.channel.get()

    expect(channel.code).toBe('wholesale')
    expect(channel.storefront_access).toBe('login_required')
    expect(channel.guest_checkout).toBe(false)
  })

  it('resolves a channel set after creation via setChannel', async () => {
    const client = createTestClient()
    client.setChannel('wholesale')

    const channel = await client.channel.get()

    expect(channel.code).toBe('wholesale')
  })
})
