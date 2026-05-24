import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { FieldGroup } from '@/components/ui/field'

interface BulkDialogProps {
  title: string
  description?: string
  submitLabel: string
  submitDisabled?: boolean
  onCancel: () => void
  onSubmit: () => void
  children: ReactNode
}

/**
 * Modal dialog used by `BulkActionBar` form actions — title/description header,
 * scrollable body wrapping a single `<FieldGroup>`, footer with Cancel/Submit.
 * The standard shape for "pick a value and apply to N selected rows" flows;
 * use a Sheet only when the form needs more space than a centered modal.
 */
export function BulkDialog({
  title,
  description,
  submitLabel,
  submitDisabled,
  onCancel,
  onSubmit,
  children,
}: BulkDialogProps) {
  const { t } = useTranslation()

  return (
    <Dialog open onOpenChange={(o) => !o && onCancel()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description && <DialogDescription>{description}</DialogDescription>}
        </DialogHeader>
        <DialogBody>
          <FieldGroup>{children}</FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" size="sm" onClick={onCancel}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" size="sm" disabled={submitDisabled} onClick={onSubmit}>
            {submitLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
