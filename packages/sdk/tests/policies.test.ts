import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'

describe('policies', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  it('lists store policies', async () => {
    const result = await client.policies.list()
    expect(result.data).toHaveLength(2)
    expect(result.data[0].slug).toBe('return-policy')
    expect(result.data[0].name).toBe('Return Policy')
    expect(result.data[0].body).toBe('Return within 30 days.')
    expect(result.data[0].body_html).toBe('<p>Return within 30 days.</p>')
  })

  it('gets a policy by slug', async () => {
    const result = await client.policies.get('return-policy')
    expect(result.id).toBe('pol_1')
    expect(result.name).toBe('Return Policy')
    expect(result.slug).toBe('return-policy')
    expect(result.body).toBe('Return within 30 days.')
    expect(result.body_html).toBe('<p>Return within 30 days.</p>')
  })
})
