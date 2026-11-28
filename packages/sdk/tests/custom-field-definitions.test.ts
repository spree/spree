import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'

describe('customFieldDefinitions', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  it('lists the fields asked at checkout, filtered by resource', async () => {
    const result = await client.customFieldDefinitions.list({ resource_type_eq: 'order' })

    expect(result.data).toHaveLength(1)
    expect(result.data[0].full_key).toBe('checkout.delivery_date')
    expect(result.data[0].validations.required).toBe(true)
  })
})
