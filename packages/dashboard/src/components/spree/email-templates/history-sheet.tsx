import type { EmailTemplateRevision } from '@spree/admin-sdk'
import {
  Button,
  RelativeTime,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { ActorLabel } from '../actor-label'

/** Published versions of a template, newest first, each one restorable into the draft. */
export function EmailTemplateHistorySheet({
  open,
  onOpenChange,
  revisions,
  isLoading,
  canRestore,
  restoring,
  onRestore,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  revisions?: EmailTemplateRevision[]
  isLoading: boolean
  canRestore: boolean
  restoring: boolean
  onRestore: (revision: EmailTemplateRevision) => void
}) {
  const { t } = useTranslation()

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{t('admin.email_templates.history.title')}</SheetTitle>
          <SheetDescription>{t('admin.email_templates.history.description')}</SheetDescription>
        </SheetHeader>
        <div className="flex flex-col gap-3 overflow-y-auto px-4 pb-4">
          {isLoading && <Skeleton className="h-24 w-full" />}
          {!isLoading && !revisions?.length && (
            <p className="text-sm text-muted-foreground">
              {t('admin.email_templates.history.empty')}
            </p>
          )}
          {revisions?.map((revision, index) => (
            <div
              key={revision.id}
              className="flex flex-col gap-2 rounded-md border border-border p-3"
            >
              <div className="flex items-center justify-between gap-2 text-sm">
                <div className="flex flex-col">
                  <span className="font-medium">
                    {index === 0
                      ? t('admin.email_templates.history.latest')
                      : t('admin.email_templates.history.version', {
                          number: revisions.length - index,
                        })}
                  </span>
                  <span className="text-muted-foreground">
                    <RelativeTime iso={revision.created_at} />
                    {revision.published_by && (
                      <>
                        {' · '}
                        <ActorLabel actor={revision.published_by} />
                      </>
                    )}
                  </span>
                </div>
                {canRestore && (
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={restoring}
                    onClick={() => onRestore(revision)}
                  >
                    {t('admin.email_templates.history.restore')}
                  </Button>
                )}
              </div>
              {revision.subject && <p className="truncate text-sm">{revision.subject}</p>}
              <pre className="max-h-40 overflow-auto rounded bg-muted p-2 font-mono text-xs">
                {revision.body}
              </pre>
            </div>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  )
}
