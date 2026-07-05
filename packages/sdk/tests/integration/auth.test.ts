import { describe, expect, it } from 'vitest'
import { client } from './helpers'
import { getCredentials } from './setup'

describe('auth', () => {
  it('logs in with email/password and returns JWT', async () => {
    const creds = getCredentials()
    const result = await client().auth.login({
      email: creds.user_email,
      password: creds.user_password,
    })

    expect(result.token).toBeDefined()
    expect(result.refresh_token).toBeDefined()
    expect(result.user.email).toBe(creds.user_email)
  })

  it('refreshes a token', async () => {
    const creds = getCredentials()
    const login = await client().auth.login({
      email: creds.user_email,
      password: creds.user_password,
    })

    const result = await client().auth.refresh({
      refresh_token: login.refresh_token,
    })

    expect(result.token).toBeDefined()
    expect(result.token).not.toBe(login.token)
  })
})
