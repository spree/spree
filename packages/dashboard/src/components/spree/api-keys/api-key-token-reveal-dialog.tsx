import type { ApiKey } from '@spree/admin-sdk'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import { AlertTriangleIcon, CheckIcon, CopyIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

/** One-shot reveal of a freshly created secret token. */
export function TokenRevealDialog({
  apiKey,
  onOpenChange,
}: {
  apiKey: ApiKey | null
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { copied, copy } = useCopyToClipboard()

  return (
    <Dialog open={!!apiKey} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.settings.api_keys.save_secret_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.pages.settings.api_keys.save_secret_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-3">
          <div className="flex items-start gap-2 rounded-md border border-yellow-200 bg-yellow-50 p-3 text-sm text-yellow-900 dark:border-yellow-900/40 dark:bg-yellow-950/40 dark:text-yellow-200">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>{t('admin.api_keys.warning_treat_like_password')}</span>
          </div>
          {apiKey?.plaintext_token && (
            <div className="flex items-center gap-2 rounded-md border border-border bg-muted/40 p-3">
              <code className="flex-1 truncate font-mono text-sm">{apiKey.plaintext_token}</code>
              <Button
                size="sm"
                variant="outline"
                onClick={() => copy(apiKey.plaintext_token ?? '')}
              >
                {copied ? <CheckIcon /> : <CopyIcon />}
                {copied ? t('admin.actions.copied') : t('admin.actions.copy')}
              </Button>
            </div>
          )}
        </DialogBody>
        <DialogFooter>
          <Button onClick={() => onOpenChange(false)}>{t('admin.actions.done')}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
