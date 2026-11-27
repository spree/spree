import { buildPermissions } from '@spree/dashboard-core'
import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it, vi } from 'vitest'

const CATALOG = [
  { key: 'read_orders', kind: 'read', resource: 'orders' },
  { key: 'write_orders', kind: 'write', resource: 'orders' },
  { key: 'read_maintenance_tasks', kind: 'read', resource: 'maintenance_tasks' },
  { key: 'write_maintenance_tasks', kind: 'write', resource: 'maintenance_tasks' },
].map((entry) => ({ ...entry, group: 'access', group_label: 'Access', label: '', description: '' }))

const ADMIN_RULES = [
  { allow: true, actions: ['manage'], subjects: ['all'], has_conditions: false },
  { allow: false, actions: ['manage'], subjects: ['maintenance_task_run'], has_conditions: false },
]
const STAFF_RULES = [
  { allow: true, actions: ['manage'], subjects: ['order'], has_conditions: false },
]

const caller = vi.hoisted(() => ({ rules: [] as typeof ADMIN_RULES, keys: [] as string[] }))

vi.mock('@spree/dashboard-core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@spree/dashboard-core')>()),
  usePermissions: () => ({
    permissions: buildPermissions(caller.rules),
    permissionKeys: caller.keys,
  }),
}))
vi.mock('../../../hooks/use-roles', () => ({
  usePermissionCatalog: () => ({ data: { data: CATALOG } }),
}))

const { ScopePicker } = await import('./api-key-scope-picker')

/** Whether the alias checkbox with this id rendered disabled. */
function aliasDisabled(html: string, id: string): boolean {
  const tag = html.match(new RegExp(`<[^>]*id="${id}"[^>]*>`))?.[0]
  if (!tag) throw new Error(`No checkbox with id ${id}`)
  return /\sdisabled=""|aria-disabled="true"/.test(tag)
}

function render(rules: typeof ADMIN_RULES, keys: string[]) {
  caller.rules = rules
  caller.keys = keys
  return renderToStaticMarkup(<ScopePicker value={[]} />)
}

describe('the API key scope picker', () => {
  // An installation with maintenance tasks turned off withholds their keys
  // from everyone; the server still lets the admin role grant every scope.
  it('offers both aliases to an admin whose keys do not cover the catalog', () => {
    const html = render(ADMIN_RULES, ['read_orders', 'write_orders'])

    expect(aliasDisabled(html, 'scope-write-all')).toBe(false)
    expect(aliasDisabled(html, 'scope-read-all')).toBe(false)
  })

  it('withholds both aliases from a staff member missing some keys', () => {
    const html = render(STAFF_RULES, ['read_orders', 'write_orders'])

    expect(aliasDisabled(html, 'scope-write-all')).toBe(true)
    expect(aliasDisabled(html, 'scope-read-all')).toBe(true)
  })

  it('offers read all to a staff member holding every read key', () => {
    const html = render(STAFF_RULES, ['read_orders', 'write_orders', 'read_maintenance_tasks'])

    expect(aliasDisabled(html, 'scope-write-all')).toBe(true)
    expect(aliasDisabled(html, 'scope-read-all')).toBe(false)
  })
})
