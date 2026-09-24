import { describe, expect, it } from 'vitest'
import { authCallbackErrorKey } from './use-auth-providers'

describe('authCallbackErrorKey', () => {
  it('maps a known callback error code to its copy', () => {
    expect(authCallbackErrorKey('account_not_provisioned')).toBe(
      'admin.auth.login.account_not_provisioned',
    )
  })

  it('falls back to the generic message for unknown and inherited names', () => {
    for (const code of ['something_else', 'constructor', '__proto__', 'toString']) {
      expect(authCallbackErrorKey(code)).toBe('admin.auth.login.sso_failed')
    }
  })
})
