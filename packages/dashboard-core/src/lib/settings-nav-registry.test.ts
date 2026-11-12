import { describe, expect, it } from 'vitest'
import { canSeeSettingsEntry, type SettingsNavEntry } from './settings-nav-registry'

const entry = (overrides: Partial<SettingsNavEntry>): SettingsNavEntry => ({
  key: 'settings.example',
  label: 'Example',
  path: '/example',
  group: 'store',
  ...overrides,
})

const allowing =
  (...subjects: string[]) =>
  (_action: string, subject: string) =>
    subjects.includes(subject)

describe('canSeeSettingsEntry', () => {
  it('shows an entry without a subject to everyone', () => {
    expect(canSeeSettingsEntry(entry({}), allowing())).toBe(true)
  })

  it('checks a single subject', () => {
    expect(canSeeSettingsEntry(entry({ subject: 'tax_rate' }), allowing('tax_rate'))).toBe(true)
    expect(canSeeSettingsEntry(entry({ subject: 'tax_rate' }), allowing())).toBe(false)
  })

  // A page of tabs is reachable through any one of them.
  it('shows an entry with several subjects when any one is allowed', () => {
    const taxes = entry({ subjects: ['tax_category', 'tax_rate', 'tax_exemption_reason'] })

    expect(canSeeSettingsEntry(taxes, allowing('tax_exemption_reason'))).toBe(true)
    expect(canSeeSettingsEntry(taxes, allowing('product'))).toBe(false)
  })
})
