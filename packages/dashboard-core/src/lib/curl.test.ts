import { describe, expect, it } from 'vitest'
import { buildCurlCommand } from './curl'

describe('buildCurlCommand', () => {
  it('uses the token placeholder and extra headers', () => {
    expect(
      buildCurlCommand('https://api.example.com/api/v3/seller/orders/or_1', {
        'X-Spree-Seller-Id': 'seller_1',
      }),
    ).toBe(
      [
        "curl 'https://api.example.com/api/v3/seller/orders/or_1'",
        '  -H "Authorization: Bearer $SPREE_API_TOKEN"',
        "  -H 'X-Spree-Seller-Id: seller_1'",
      ].join(' \\\n'),
    )
  })
})
