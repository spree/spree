import { usePermissions } from '@spree/dashboard-core'
import { Checkbox, cn, Skeleton } from '@spree/dashboard-ui'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { usePermissionCatalog } from '../../../hooks/use-roles'
import { PermissionGrid } from '../permission-picker'

// `disabled` renders the whole picker read-only — used when editing an existing
// key, whose scopes are fixed for its lifetime (the server rejects scope edits).
export function ScopePicker({
  value,
  onChange,
  disabled = false,
}: {
  value: string[]
  onChange?: (next: string[]) => void
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const { data: catalog } = usePermissionCatalog()
  const { permissionKeys } = usePermissions()
  const hasWriteAll = value.includes('write_all')
  const hasReadAll = value.includes('read_all')

  // A staffer can only mint scopes within their own grant (the server's
  // anti-amplification guard) — don't offer keys it would reject. A caller
  // holding the whole catalog (admin) is unrestricted, including the aliases.
  const blockedKeys = useMemo(() => {
    if (!catalog) return undefined
    const blocked = new Set(
      catalog.data.filter((entry) => !permissionKeys.includes(entry.key)).map((entry) => entry.key),
    )
    return blocked.size > 0 ? blocked : undefined
  }, [catalog, permissionKeys])
  const writeAllBlocked = blockedKeys !== undefined
  const readAllBlocked =
    !!catalog &&
    catalog.data.some((entry) => entry.kind === 'read' && !permissionKeys.includes(entry.key))

  function setAllRead(checked: boolean) {
    let next = value.filter((v) => v !== 'read_all' && !v.startsWith('read_'))
    if (checked) next = [...next, 'read_all']
    onChange?.(next)
  }

  function setAllWrite(checked: boolean) {
    let next = value.filter((v) => v !== 'write_all' && !v.startsWith('write_'))
    if (checked) next = [...next, 'write_all']
    onChange?.(next)
  }

  return (
    <div className={cn('flex flex-col gap-3', disabled && 'opacity-70')}>
      {/* Quick access: write_all / read_all toggles. Selecting one blocks the
          per-resource grid because the catch-all already covers it. */}
      <div className="flex flex-col gap-2 rounded-md border border-border bg-muted/30 p-3">
        <label htmlFor="scope-write-all" className="flex cursor-pointer items-center gap-2 text-sm">
          <Checkbox
            id="scope-write-all"
            checked={hasWriteAll}
            onCheckedChange={setAllWrite}
            disabled={disabled || writeAllBlocked}
          />
          <span className="font-medium">{t('admin.api_keys.scope_picker.full_access_label')}</span>
          <span className="text-xs text-muted-foreground">
            {t('admin.api_keys.scope_picker.full_access_hint')}
          </span>
        </label>
        <label htmlFor="scope-read-all" className="flex cursor-pointer items-center gap-2 text-sm">
          <Checkbox
            id="scope-read-all"
            checked={hasReadAll}
            onCheckedChange={setAllRead}
            disabled={disabled || hasWriteAll || readAllBlocked}
          />
          <span className="font-medium">{t('admin.api_keys.scope_picker.read_all_label')}</span>
          <span className="text-xs text-muted-foreground">
            {t('admin.api_keys.scope_picker.read_all_hint')}
          </span>
        </label>
      </div>

      <div
        className={cn(!disabled && (hasWriteAll || hasReadAll) && 'pointer-events-none opacity-50')}
      >
        {catalog ? (
          <PermissionGrid
            entries={catalog.data}
            value={value}
            onChange={(next) => onChange?.(next)}
            disabled={disabled}
            disabledKeys={blockedKeys}
          />
        ) : (
          <div className="flex flex-col gap-2 p-3">
            <Skeleton className="h-6 w-full" />
            <Skeleton className="h-6 w-full" />
            <Skeleton className="h-6 w-full" />
          </div>
        )}
      </div>
    </div>
  )
}
