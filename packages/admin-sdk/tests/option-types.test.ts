import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleOptionType = {
  id: 'opt_abc123',
  name: 'color',
  presentation: 'Color',
  position: 1,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('optionTypes', () => {
  describe('list', () => {
    it('GETs /option_types and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/option_types`, () =>
          HttpResponse.json(paginated([sampleOptionType])),
        ),
      )

      const res = await createTestClient().optionTypes.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('opt_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/option_types`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().optionTypes.list({ name_cont: 'col', presentation_eq: 'Color' })

      expect(url!.searchParams.get('q[name_cont]')).toBe('col')
      expect(url!.searchParams.get('q[presentation_eq]')).toBe('Color')
    })
  })

  describe('get', () => {
    it('GETs /option_types/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/option_types/opt_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleOptionType)
        }),
      )

      const res = await createTestClient().optionTypes.get('opt_abc123', {
        expand: ['option_values'],
      })

      expect(res.id).toBe('opt_abc123')
      expect(url!.searchParams.get('expand')).toBe('option_values')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/option_types`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleOptionType, { status: 201 })
        }),
      )

      await createTestClient().optionTypes.create({
        name: 'color',
        presentation: 'Color',
        option_values: [{ name: 'red', presentation: 'Red' }],
      })

      expect(body).toEqual({
        name: 'color',
        presentation: 'Color',
        option_values: [{ name: 'red', presentation: 'Red' }],
      })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/option_types/opt_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleOptionType, presentation: 'Colour' })
        }),
      )

      const res = await createTestClient().optionTypes.update('opt_abc123', {
        presentation: 'Colour',
      })

      expect(body).toEqual({ presentation: 'Colour' })
      expect(res.presentation).toBe('Colour')
    })

    it('DELETEs /option_types/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/option_types/opt_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().optionTypes.delete('opt_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})
