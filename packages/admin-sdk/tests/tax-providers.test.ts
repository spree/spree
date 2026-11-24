import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient } from './helpers'
import { server } from './mocks/server'

describe('taxProviders', () => {
  describe('taxCodes', () => {
    it("GETs the engine's tax codes for the query", async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/tax_providers/avalara/tax_codes`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json({
            data: [{ code: 'PC040100', description: 'Clothing and related products' }],
          })
        }),
      )

      const res = await createTestClient().taxProviders.taxCodes('avalara', { q: 'clothing' })

      expect(url!.searchParams.get('q')).toBe('clothing')
      expect(res.data).toEqual([{ code: 'PC040100', description: 'Clothing and related products' }])
    })
  })
})
