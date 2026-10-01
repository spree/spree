import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const id = 'spree.order_mailer.confirm_email'

describe('emailTemplates', () => {
  it('get sends the language with the expansions', async () => {
    let url: URL | null = null
    server.use(
      http.get(`${API_PREFIX}/email_templates/${id}`, ({ request }) => {
        url = new URL(request.url)
        return HttpResponse.json({ id })
      }),
    )

    await createTestClient().emailTemplates.get(id, {
      language: 'de',
      expand: ['draft.updated_by'],
    })

    expect(url!.searchParams.get('language')).toBe('de')
    expect(url!.searchParams.get('expand')).toBe('draft.updated_by')
  })

  it('revisions.list sends the language as itself, not as a filter', async () => {
    let url: URL | null = null
    server.use(
      http.get(`${API_PREFIX}/email_templates/${id}/revisions`, ({ request }) => {
        url = new URL(request.url)
        return HttpResponse.json(paginated([]))
      }),
    )

    await createTestClient().emailTemplates.revisions.list(id, { language: 'de', page: 2 })

    expect(url!.searchParams.get('language')).toBe('de')
    expect(url!.searchParams.get('q[language]')).toBeNull()
    expect(url!.searchParams.get('page')).toBe('2')
  })
})
