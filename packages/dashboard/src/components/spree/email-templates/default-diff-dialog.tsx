import {
  Button,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@spree/dashboard-ui'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { type DiffRow, diffLines } from '../../../lib/line-diff'

const CELL_TONE: Record<DiffRow['kind'], { before: string; after: string }> = {
  same: { before: '', after: '' },
  removed: { before: 'bg-danger-bg', after: '' },
  added: { before: '', after: 'bg-success-bg' },
  changed: { before: 'bg-danger-bg', after: 'bg-success-bg' },
}

/**
 * Spree's default as the store's version started from it, next to the default
 * now, so a merchant can see what an upgrade changed before deciding.
 */
export function DefaultDiffDialog({
  open,
  onOpenChange,
  before,
  after,
  pending,
  onKeepMine,
  onStartOver,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  before: string
  after: string
  pending: boolean
  onKeepMine: () => void
  onStartOver: () => void
}) {
  const { t } = useTranslation()
  const rows = useMemo(() => (open ? diffLines(before, after) : []), [open, before, after])

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[min(1100px,calc(100%-2rem))]">
        <DialogHeader>
          <DialogTitle>{t('admin.email_templates.default_update.dialog_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.email_templates.default_update.dialog_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="overflow-auto">
          <table className="w-full table-fixed border-collapse font-mono text-xs">
            <thead>
              <tr className="text-left text-muted-foreground">
                <th className="px-2 py-1 font-medium">
                  {t('admin.email_templates.default_update.before')}
                </th>
                <th className="px-2 py-1 font-medium">
                  {t('admin.email_templates.default_update.after')}
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                // biome-ignore lint/suspicious/noArrayIndexKey: rows have no identity beyond their position
                <tr key={index}>
                  <td
                    className={cn(
                      'whitespace-pre-wrap break-all px-2 align-top',
                      CELL_TONE[row.kind].before,
                    )}
                  >
                    {row.before}
                  </td>
                  <td
                    className={cn(
                      'whitespace-pre-wrap break-all px-2 align-top',
                      CELL_TONE[row.kind].after,
                    )}
                  >
                    {row.after}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </DialogBody>
        <DialogFooter>
          <Button variant="outline" disabled={pending} onClick={onStartOver}>
            {t('admin.email_templates.default_update.start_over')}
          </Button>
          <Button disabled={pending} onClick={onKeepMine}>
            {t('admin.email_templates.default_update.keep_mine')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
