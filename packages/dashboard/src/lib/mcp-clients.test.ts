import { describe, expect, it } from 'vitest'
import { hostOf, KNOWN_CLIENTS, knownClientNamed, publishedCallback } from './mcp-clients'

const claude = KNOWN_CLIENTS[0]

describe('knownClientNamed', () => {
  it('matches a known name whatever its case or spacing', () => {
    expect(knownClientNamed('Claude')?.value).toBe('claude')
    expect(knownClientNamed('  claude ')?.value).toBe('claude')
    expect(knownClientNamed('Claude Desktop')?.value).toBe('claude')
  })

  it('does not match an unrelated name', () => {
    expect(knownClientNamed('Claudette inventory')).toBeUndefined()
    expect(knownClientNamed('CI client')).toBeUndefined()
  })
})

describe('publishedCallback', () => {
  it('accepts the callbacks the client publishes', () => {
    expect(publishedCallback(claude, 'https://claude.ai/api/mcp/auth_callback')).toBe(true)
  })

  it('accepts a loopback address on any port', () => {
    expect(publishedCallback(claude, 'http://127.0.0.1:51234/callback')).toBe(true)
    expect(publishedCallback(claude, 'http://localhost:3000/cb')).toBe(true)
  })

  it('refuses any other host, including a look-alike', () => {
    expect(publishedCallback(claude, 'https://claude.ai.attacker.example/callback')).toBe(false)
    expect(publishedCallback(claude, 'https://chatgpt.com/connector_platform_oauth_redirect')).toBe(
      false,
    )
    expect(publishedCallback(claude, 'not a url')).toBe(false)
  })
})

describe('hostOf', () => {
  it('names the host a callback hands the browser to', () => {
    expect(hostOf('https://example.test/callback?x=1')).toBe('example.test')
    expect(hostOf('nope')).toBeNull()
  })
})
