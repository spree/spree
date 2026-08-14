import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleTaxRate = {
  id: 'txr_abc123',
  name: 'German VAT',
  // A string on the wire: the serializer emits amount as a decimal string, and
  // the numeric form is the separate amount_percentage.
  amount: '0.19',
  amount_percentage: 19.0,
  country_iso: 'DE',
  state_code: null,
  included_in_price: true,
  show_rate_in_label: true,
  created_at: '2026-08-01T00:00:00Z',
  updated_at: '2026-08-01T00:00:00Z',
}

describe('taxRates', () => {
  it('lists rates and wraps Ransack predicates', async () => {
    let url: URL | null = null
    server.use(
      http.get(`${API_PREFIX}/tax_rates`, ({ request }) => {
        url = new URL(request.url)
        return HttpResponse.json(paginated([sampleTaxRate]))
      }),
    )

    const res = await createTestClient().taxRates.list({ country_iso_eq: 'DE' })

    expect(res.data[0]?.id).toBe('txr_abc123')
    expect(url!.searchParams.get('q[country_iso_eq]')).toBe('DE')
  })

  // A rate names its jurisdiction directly rather than pointing at a zone.
  it('creates a rate against a country and state', async () => {
    let body: Record<string, unknown> | null = null
    server.use(
      http.post(`${API_PREFIX}/tax_rates`, async ({ request }) => {
        body = (await request.json()) as Record<string, unknown>
        return HttpResponse.json(sampleTaxRate, { status: 201 })
      }),
    )

    await createTestClient().taxRates.create({
      name: 'California Sales Tax',
      amount: 0.0825,
      country_iso: 'US',
      state_code: 'CA',
      tax_category_id: 'txc_1',
    })

    expect(body).toEqual({
      name: 'California Sales Tax',
      amount: 0.0825,
      country_iso: 'US',
      state_code: 'CA',
      tax_category_id: 'txc_1',
    })
  })

  it('updates and deletes a rate', async () => {
    let deleted = false
    server.use(
      http.patch(`${API_PREFIX}/tax_rates/txr_abc123`, () =>
        HttpResponse.json({ ...sampleTaxRate, amount: '0.2', amount_percentage: 20.0 }),
      ),
      http.delete(`${API_PREFIX}/tax_rates/txr_abc123`, () => {
        deleted = true
        return new HttpResponse(null, { status: 204 })
      }),
    )

    const client = createTestClient()
    const updated = await client.taxRates.update('txr_abc123', { amount: 0.2 })
    await client.taxRates.delete('txr_abc123')

    expect(updated.amount).toBe('0.2')
    expect(deleted).toBe(true)
  })
})
