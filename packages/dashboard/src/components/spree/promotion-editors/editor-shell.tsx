import { Button, SheetFooter } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Shared layout for promotion rule and action editors. Wraps the body
 * in the standard scroll container and renders a save/cancel footer
 * — both behaviors that all built-in editors share. Editors only
 * provide their fields and a save handler.
 */
export function EditorShell({
  children,
  onSave,
  onCancel,
  pending,
  saveLabel,
  saveDisabled,
}: {
  children: ReactNode
  onSave: () => void | Promise<void>
  onCancel: () => void
  pending: boolean
  saveLabel?: string
  saveDisabled?: boolean
}) {
  const { t } = useTranslation()
  const resolvedSaveLabel = saveLabel ?? t('admin.actions.save')

  return (
    <>
      <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">{children}</div>
      <SheetFooter>
        <Button type="button" variant="outline" size="sm" onClick={onCancel} disabled={pending}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" size="sm" onClick={() => onSave()} disabled={pending || saveDisabled}>
          {pending ? t('admin.actions.saving') : resolvedSaveLabel}
        </Button>
      </SheetFooter>
    </>
  )
}
