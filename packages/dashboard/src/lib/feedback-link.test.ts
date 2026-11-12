import type { DeveloperInspectorEntry } from '@spree/dashboard-core'
import { describe, expect, it } from 'vitest'
import { failedRequestLines, feedbackLink, feedbackMarkdown } from './feedback-link'

const ISSUE_FORM = 'https://github.com/spree/spree/issues/new?template=bug_report.yml'

const failed: DeveloperInspectorEntry = {
  id: 1,
  method: 'POST',
  path: '/api/v3/admin/orders/or_1/complete',
  query: { q: 'jane@example.com' },
  url: 'http://localhost/api/v3/admin/orders/or_1/complete?q=jane@example.com',
  status: 500,
  durationMs: 10,
  requestId: 'req-1',
  requestHeaders: {},
  requestBody: { email: 'jane@example.com' },
  responseBody: { error: { message: 'jane@example.com is taken' } },
  errorCode: 'internal_server_error',
  errorMessage: 'jane@example.com is taken',
}

describe('failedRequestLines', () => {
  it('keeps the method, path, status, code and request ID, never customer data', () => {
    const lines = failedRequestLines([failed])

    expect(lines).toBe(
      'POST /api/v3/admin/orders/or_1/complete 500 internal_server_error request_id=req-1',
    )
    expect(lines).not.toContain('jane')
  })

  it('drops a query string written into the path', () => {
    const lines = failedRequestLines([
      { ...failed, path: '/api/v3/admin/customers?q=jane@example.com' },
    ])

    expect(lines).toBe('POST /api/v3/admin/customers 500 internal_server_error request_id=req-1')
  })
})

describe('feedbackLink', () => {
  it('fills a bug into the issue form', () => {
    const link = feedbackLink('bug', {
      message: 'Checkout fails',
      logs: 'POST /x 500',
      diagnostics: '<details>r</details>',
    })

    expect(link.paste).toBeNull()
    const params = new URL(link.url).searchParams
    expect(params.get('template')).toBe('bug_report.yml')
    expect(params.get('description')).toBe('Checkout fails')
    expect(params.get('logs')).toBe('POST /x 500')
    expect(params.get('environment')).toBe('<details>r</details>')
  })

  it('leaves the diagnostics to paste when the link would be too long', () => {
    const diagnostics = 'x'.repeat(5900)
    const link = feedbackLink('bug', { message: 'Checkout fails', diagnostics })

    expect(link.paste).toBe(diagnostics)
    const params = new URL(link.url).searchParams
    expect(params.get('environment')).toBeNull()
    expect(params.get('description')).toBe('Checkout fails')
  })

  it('pastes everything when not even the message fits', () => {
    const input = { message: 'y'.repeat(7000) }
    const link = feedbackLink('bug', input)

    expect(link.url).toBe(ISSUE_FORM)
    expect(link.paste).toBe(feedbackMarkdown('bug', input))
  })

  it('opens an idea as a discussion, titled by its first line', () => {
    const link = feedbackLink('idea', {
      message: 'Bulk edit prices\nFor a whole collection at once',
      spreeVersion: '6.0.4',
    })

    const url = new URL(link.url)
    expect(url.pathname).toBe('/orgs/spree/discussions/new')
    expect(url.searchParams.get('category')).toBe('ideas')
    expect(url.searchParams.get('title')).toBe('Bulk edit prices')
    expect(url.searchParams.get('body')).toBe(
      'Bulk edit prices\nFor a whole collection at once\n\n---\nSpree 6.0.4',
    )
  })

  it('opens anything else in the general discussions', () => {
    const link = feedbackLink('other', { message: 'Love the new dashboard' })

    expect(new URL(link.url).searchParams.get('category')).toBe('general')
  })
})
