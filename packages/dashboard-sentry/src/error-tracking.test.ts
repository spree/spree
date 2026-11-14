import { describe, expect, it } from 'vitest'
import {
  errorTrackingEnabled,
  panelFromPackages,
  scrubBreadcrumb,
  scrubErrorEvent,
} from './error-tracking'

describe('errorTrackingEnabled', () => {
  it('needs a DSN', () => {
    expect(
      errorTrackingEnabled({ dsn: '', production: true, enableInDevelopment: undefined }),
    ).toBe(false)
  })

  it('reports from production builds', () => {
    expect(
      errorTrackingEnabled({
        dsn: 'https://k@o1.ingest.sentry.io/1',
        production: true,
        enableInDevelopment: undefined,
      }),
    ).toBe(true)
  })

  it('stays off in development unless asked', () => {
    const dsn = 'https://k@o1.ingest.sentry.io/1'
    expect(errorTrackingEnabled({ dsn, production: false, enableInDevelopment: undefined })).toBe(
      false,
    )
    expect(errorTrackingEnabled({ dsn, production: false, enableInDevelopment: 'true' })).toBe(true)
  })
})

describe('scrubErrorEvent', () => {
  it('redacts tokens in the page URL and Referer', () => {
    const event = scrubErrorEvent({
      type: undefined,
      request: {
        url: 'https://app.test/dashboard/reset-password?token=abc',
        headers: { Referer: 'https://app.test/dashboard/accept-invitation/inv_1?token=def' },
      },
    })
    expect(event.request?.url).toBe('https://app.test/dashboard/reset-password?token=redacted')
    expect(event.request?.headers?.Referer).toBe(
      'https://app.test/dashboard/accept-invitation/inv_1?token=redacted',
    )
  })

  it('redacts tokens in the error message', () => {
    const event = scrubErrorEvent({
      type: undefined,
      message: 'Lookup failed for /auth/invitations/inv_1/lookup?token=abc',
      exception: {
        values: [{ type: 'Error', value: 'PATCH /auth/password_resets/abc failed' }],
      },
    })
    expect(event.message).toBe('Lookup failed for /auth/invitations/inv_1/lookup?token=redacted')
    expect(event.exception?.values?.[0]?.value).toBe('PATCH /auth/password_resets/redacted failed')
  })
})

describe('panelFromPackages', () => {
  it('names the panel the build bundles', () => {
    expect(panelFromPackages({ '@spree/dashboard': '6.0.4' })).toBe('admin')
    expect(panelFromPackages({ '@spree/seller-dashboard': '6.0.4' })).toBe('seller')
    expect(panelFromPackages(undefined)).toBeUndefined()
  })
})

describe('scrubBreadcrumb', () => {
  it('redacts tokens in navigation and request breadcrumbs', () => {
    const navigation = scrubBreadcrumb({
      category: 'navigation',
      data: { from: '/dashboard/reset-password?token=abc', to: '/dashboard/login' },
    })
    expect(navigation.data).toEqual({
      from: '/dashboard/reset-password?token=redacted',
      to: '/dashboard/login',
    })

    const request = scrubBreadcrumb({
      category: 'fetch',
      data: { url: '/api/v3/admin/auth/confirm?token=abc', status_code: 200 },
    })
    expect(request.data).toEqual({
      url: '/api/v3/admin/auth/confirm?token=redacted',
      status_code: 200,
    })

    const reset = scrubBreadcrumb({
      category: 'fetch',
      data: { method: 'PATCH', url: '/api/v3/admin/auth/password_resets/abc' },
    })
    expect(reset.data?.url).toBe('/api/v3/admin/auth/password_resets/redacted')
  })

  it('redacts tokens in console breadcrumbs', () => {
    const log = scrubBreadcrumb({
      category: 'console',
      message: 'Error: could not open /dashboard/reset-password?token=abc',
    })
    expect(log.message).toBe('Error: could not open /dashboard/reset-password?token=redacted')
  })

  it('redacts percent-encoded tokens inside another URL', () => {
    const navigation = scrubBreadcrumb({
      category: 'navigation',
      data: {
        to: '/login?redirect=%2Freset-password%3Ftoken%3Dabc%26step%3D2',
        from: '/x?next=%2Fapi%2Fv3%2Fadmin%2Fauth%2Fpassword_resets%2Fabc%3Fa%3D1',
      },
    })
    expect(navigation.data).toEqual({
      to: '/login?redirect=%2Freset-password%3Ftoken%3Dredacted%26step%3D2',
      from: '/x?next=%2Fapi%2Fv3%2Fadmin%2Fauth%2Fpassword_resets%2Fredacted%3Fa%3D1',
    })
  })

  it('redacts a token after the hash', () => {
    expect(scrubBreadcrumb({ message: '/reset-password#token=abc' }).message).toBe(
      '/reset-password#token=redacted',
    )
  })
})
