import { afterEach, describe, expect, it } from 'vitest'
import { __getNavEntries, __resetNavRegistry, nav } from '../src/lib/nav-registry'
import { Subject } from '../src/lib/permissions'
import {
  __resetSettingsNavRegistry,
  hasVisibleSettingsEntries,
  settingsNav,
} from '../src/lib/settings-nav-registry'

/** Minimal stand-in for the PermissionProvider's matcher. */
function permissionsFor(granted: Array<[string, string]>) {
  return {
    can: (action: string, subject: string) =>
      granted.some(([a, s]) => a === action && s === subject),
  }
}

function registerSettingsPages() {
  settingsNav.addGroup({ key: 'store', label: 'Store' })
  settingsNav.addGroup({ key: 'team', label: 'Team' })
  // Every staff member can read the store (shell data), so the store settings
  // page declares `update` — a read gate would show it to everyone.
  settingsNav.add({
    key: 'settings.store',
    label: 'Store',
    path: '/store',
    group: 'store',
    subject: 'store',
    action: 'update',
  })
  settingsNav.add({
    key: 'settings.roles',
    label: 'Roles',
    path: '/roles',
    group: 'team',
    subject: 'role',
  })
}

afterEach(() => __resetSettingsNavRegistry())

describe('settings nav visibility', () => {
  it('hides update-gated pages from a role that can only read the subject', () => {
    registerSettingsPages()

    // An order manager: reads the store for shell data, manages nothing here.
    const orderManager = permissionsFor([
      ['read', 'store'],
      ['manage', 'order'],
    ])

    expect(hasVisibleSettingsEntries(orderManager)).toBe(false)
  })

  it('shows the page to a role that can update the subject', () => {
    registerSettingsPages()

    const settingsManager = permissionsFor([
      ['read', 'store'],
      ['update', 'store'],
    ])

    expect(hasVisibleSettingsEntries(settingsManager)).toBe(true)
  })

  it('shows read-gated pages to a role holding that read', () => {
    registerSettingsPages()

    expect(hasVisibleSettingsEntries(permissionsFor([['read', 'role']]))).toBe(true)
  })

  it('treats entries without a subject as always visible', () => {
    settingsNav.addGroup({ key: 'audit', label: 'Audit' })
    settingsNav.add({ key: 'settings.open', label: 'Open', path: '/open', group: 'audit' })

    expect(hasVisibleSettingsEntries(permissionsFor([]))).toBe(true)
  })

  it('is false when nothing is registered or permissions are missing', () => {
    expect(hasVisibleSettingsEntries(permissionsFor([]))).toBe(false)

    registerSettingsPages()
    expect(hasVisibleSettingsEntries(undefined)).toBe(false)
  })
})

describe('main nav visibility', () => {
  afterEach(() => __resetNavRegistry())

  // Getting Started walks a merchant through store setup, so it needs the
  // authority those tasks require — not the store read every staffer has.
  it('hides update-gated entries from a role that can only read the subject', () => {
    nav.add({
      key: 'getting-started',
      label: 'Getting Started',
      path: '/getting-started',
      subject: 'store',
      action: 'update',
    })
    nav.add({ key: 'orders', label: 'Orders', path: '/orders', subject: 'order' })

    const orderManager = permissionsFor([
      ['read', 'store'],
      ['read', 'order'],
    ])
    const visible = navEntriesFor(orderManager)

    expect(visible).toContain('orders')
    expect(visible).not.toContain('getting-started')
  })

  it('shows them to a role that can update the subject', () => {
    nav.add({
      key: 'getting-started',
      label: 'Getting Started',
      path: '/getting-started',
      subject: 'store',
      action: 'update',
    })

    expect(navEntriesFor(permissionsFor([['update', 'store']]))).toContain('getting-started')
  })
})

/** Mirrors AppSidebar's filter: `action` defaults to `read`. */
function navEntriesFor(permissions: { can: (action: string, subject: string) => boolean }) {
  return __getNavEntries()
    .filter((e) => !e.subject || permissions.can(e.action ?? 'read', e.subject))
    .map((e) => e.key)
}

describe('Subject', () => {
  // The /me endpoints send short names; a class name here never matches a rule.
  it('names every subject by its short name', () => {
    for (const value of Object.values(Subject)) expect(value).toMatch(/^[a-z][a-z_]*$/)
  })
})
