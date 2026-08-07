import type { Permission } from '@spree/admin-sdk'
import { Checkbox, cn } from '@spree/dashboard-ui'
import type { TFunction } from 'i18next'
import { Fragment } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * One picker row: a catalog resource with its read key and (usually) write
 * key. Built from the `/admin/permissions` catalog entries, so extensions'
 * registered resources appear automatically.
 */
export interface PermissionRow {
  resource: string
  group: string
  groupLabel: string
  label: string
  description: string
  readKey: string
  writeKey?: string
}

export function buildPermissionRows(entries: Permission[]): PermissionRow[] {
  const rows = new Map<string, PermissionRow>()
  for (const entry of entries) {
    const existing = rows.get(entry.resource)
    if (existing) {
      if (entry.kind === 'write') existing.writeKey = entry.key
      continue
    }
    rows.set(entry.resource, {
      resource: entry.resource,
      group: entry.group,
      groupLabel: entry.group_label,
      label: entry.label,
      description: entry.description,
      readKey: entry.kind === 'read' ? entry.key : `read_${entry.resource}`,
      writeKey: entry.kind === 'write' ? entry.key : undefined,
    })
  }
  return [...rows.values()]
}

/** Every read key in the catalog — the "Read only" preset. */
export function allReadKeys(entries: Permission[]): string[] {
  return entries.filter((entry) => entry.kind === 'read').map((entry) => entry.key)
}

/** Every write key in the catalog (read is implied) plus read-only resources' read keys. */
export function allWriteKeys(entries: Permission[]): string[] {
  return buildPermissionRows(entries).map((row) => row.writeKey ?? row.readKey)
}

/**
 * Human label for a catalog key — "View Orders", "Manage Products" — in the
 * admin's UI language, falling back to the raw key while the catalog loads or
 * for keys it no longer knows.
 */
export function permissionKeyLabel(
  t: TFunction,
  entries: Permission[] | undefined,
  key: string,
): string {
  const entry = entries?.find((candidate) => candidate.key === key)
  if (!entry) return key

  const resource = t(`admin.permissions.resources.${entry.resource}`, {
    defaultValue: entry.label,
  })
  return t(`admin.permissions.labels.${entry.kind}`, { resource, defaultValue: key })
}

/**
 * Shared read/write permission grid over the catalog — used by the role
 * editor and the API-key scope picker (which layers its `read_all`/`write_all`
 * alias toggles on top). Grouped by catalog group; checking write implies
 * read, mirrored in the UI by locking the read checkbox.
 *
 * Row labels translate client-side (`admin.permissions.resources.<resource>`)
 * so they follow the admin's UI language; unknown resources (extensions) fall
 * back to the server-localized label from the catalog entry.
 */
export function PermissionGrid({
  entries,
  value,
  onChange,
  disabled = false,
  disabledKeys,
}: {
  entries: Permission[]
  value: string[]
  onChange?: (next: string[]) => void
  /** Renders the whole grid read-only. */
  disabled?: boolean
  /** Keys the caller may not grant (beyond their own) — rendered disabled. */
  disabledKeys?: Set<string>
}) {
  const { t } = useTranslation()
  const rows = buildPermissionRows(entries)
  const groups: { group: string; groupLabel: string; rows: PermissionRow[] }[] = []
  for (const row of rows) {
    const bucket = groups.find((candidate) => candidate.group === row.group)
    if (bucket) {
      bucket.rows.push(row)
    } else {
      groups.push({ group: row.group, groupLabel: row.groupLabel, rows: [row] })
    }
  }

  function toggle(key: string) {
    onChange?.(value.includes(key) ? value.filter((v) => v !== key) : [...value, key])
  }

  return (
    <div className={cn('flex flex-col rounded-md border border-border', disabled && 'opacity-70')}>
      <div className="grid grid-cols-[1fr_auto_auto] items-center gap-x-6 gap-y-2 p-3 text-sm">
        <span className="font-medium text-muted-foreground">
          {t('admin.permissions.grid.resource_header')}
        </span>
        <span className="w-12 text-center font-medium text-muted-foreground">
          {t('admin.permissions.grid.read_header')}
        </span>
        <span className="w-12 text-center font-medium text-muted-foreground">
          {t('admin.permissions.grid.write_header')}
        </span>

        {groups.map((group) => (
          <GroupRows
            key={group.group}
            group={group}
            value={value}
            disabled={disabled}
            disabledKeys={disabledKeys}
            onToggle={toggle}
          />
        ))}
      </div>
    </div>
  )
}

function GroupRows({
  group,
  value,
  disabled,
  disabledKeys,
  onToggle,
}: {
  group: { group: string; groupLabel: string; rows: PermissionRow[] }
  value: string[]
  disabled: boolean
  disabledKeys?: Set<string>
  onToggle: (key: string) => void
}) {
  const { t } = useTranslation()

  return (
    <>
      <span className="col-span-3 mt-2 border-t border-border pt-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground first:mt-0 first:border-t-0 first:pt-0">
        {t(`admin.permissions.groups.${group.group}`, { defaultValue: group.groupLabel })}
      </span>
      {group.rows.map((row) => {
        const hasWrite = row.writeKey ? value.includes(row.writeKey) : false
        const hasRead = value.includes(row.readKey) || hasWrite
        const readBlocked = disabledKeys?.has(row.readKey) ?? false
        const writeBlocked = row.writeKey ? (disabledKeys?.has(row.writeKey) ?? false) : true
        const label = t(`admin.permissions.resources.${row.resource}`, {
          defaultValue: row.label,
        })
        return (
          <Fragment key={row.resource}>
            <span className="flex flex-col">
              <span>{label}</span>
              <span className="text-xs text-muted-foreground">
                {t(`admin.permissions.descriptions.${row.resource}`, {
                  defaultValue: row.description,
                })}
              </span>
            </span>
            <Checkbox
              checked={hasRead}
              onCheckedChange={() => onToggle(row.readKey)}
              // Checking write implies read on the server; lock the read box so
              // the UI can't look out of sync with what will be enforced.
              disabled={disabled || hasWrite || readBlocked}
              aria-label={t('admin.permissions.grid.read_aria', { resource: label })}
              className="justify-self-center"
            />
            {row.writeKey ? (
              <Checkbox
                checked={hasWrite}
                onCheckedChange={() => onToggle(row.writeKey as string)}
                disabled={disabled || writeBlocked}
                aria-label={t('admin.permissions.grid.write_aria', { resource: label })}
                className="justify-self-center"
              />
            ) : (
              <span className="justify-self-center text-xs text-muted-foreground">—</span>
            )}
          </Fragment>
        )
      })}
    </>
  )
}
