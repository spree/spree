import {
  Button,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/** Someone else saved the draft first: keep editing, take theirs, or overwrite it. */
export function EmailTemplateConflictDialog({
  message,
  onReload,
  onOverwrite,
  onClose,
}: {
  message: string | null
  onReload: () => void
  onOverwrite: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()

  return (
    <Dialog open={!!message} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.email_templates.conflict.title')}</DialogTitle>
          <DialogDescription>{message}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('admin.email_templates.conflict.keep_editing')}
          </Button>
          <Button variant="outline" onClick={onReload}>
            {t('admin.email_templates.conflict.reload')}
          </Button>
          <Button variant="destructive" onClick={onOverwrite}>
            {t('admin.email_templates.conflict.overwrite')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
