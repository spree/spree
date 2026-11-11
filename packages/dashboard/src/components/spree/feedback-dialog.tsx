import { isFailedEntry, useDeveloperInspectorEntries, useStore } from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldLabel,
  Skeleton,
  Tabs,
  TabsList,
  TabsTrigger,
  Textarea,
  toastManager,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import { ExternalLinkIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useDiagnostics } from '../../hooks/use-diagnostics'
import { type FeedbackKind, failedRequestLines, feedbackLink } from '../../lib/feedback-link'

const FAILED_REQUEST_LIMIT = 5
const KINDS: FeedbackKind[] = ['bug', 'idea', 'other']

/**
 * Feedback for the Spree team on GitHub: a bug opens the issue form with this
 * tab's recent failed requests and the anonymised system info filled in; an
 * idea or anything else opens a discussion. Nothing is sent from here; the
 * admin posts it on GitHub.
 */
export function FeedbackDialog({
  open,
  onOpenChange,
  kind,
  onKindChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  kind: FeedbackKind
  onKindChange: (kind: FeedbackKind) => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.feedback.title')}</DialogTitle>
          <DialogDescription>{t('admin.feedback.description')}</DialogDescription>
        </DialogHeader>
        {open && (
          <FeedbackForm
            kind={kind}
            onKindChange={onKindChange}
            onClose={() => onOpenChange(false)}
          />
        )}
      </DialogContent>
    </Dialog>
  )
}

function FeedbackForm({
  kind,
  onKindChange,
  onClose,
}: {
  kind: FeedbackKind
  onKindChange: (kind: FeedbackKind) => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const diagnostics = useDiagnostics()
  const { copy } = useCopyToClipboard()
  const failed = useDeveloperInspectorEntries().filter(isFailedEntry).slice(0, FAILED_REQUEST_LIMIT)
  const [message, setMessage] = useState('')
  const [includeFailed, setIncludeFailed] = useState(true)
  const report = diagnostics.data
  const bug = kind === 'bug'

  const input = {
    message: message.trim(),
    logs: bug && includeFailed ? failedRequestLines(failed) : undefined,
    diagnostics: bug ? report?.markdown : undefined,
    spreeVersion: report?.spree_version,
  }

  // The tab opens within the click, before any await: a browser blocks a
  // popup opened after one.
  const openOnGitHub = async () => {
    const link = feedbackLink(kind, input)
    const copying = link.paste ? copy(link.paste) : null
    window.open(link.url, '_blank', 'noopener')
    onClose()
    if (!copying) return
    toastManager.add(
      (await copying)
        ? { type: 'info', title: t('admin.feedback.copied_to_paste') }
        : { type: 'error', title: t('admin.feedback.copy_failed') },
    )
  }

  return (
    <>
      <DialogBody className="flex flex-col gap-4">
        <Tabs value={kind} onValueChange={(value) => onKindChange(value as FeedbackKind)}>
          <TabsList className="w-full">
            {KINDS.map((option) => (
              <TabsTrigger key={option} value={option} className="flex-1">
                {t(`admin.feedback.kinds.${option}`)}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>

        <Field>
          <FieldLabel htmlFor="feedback-message">{t(`admin.feedback.message.${kind}`)}</FieldLabel>
          <Textarea
            id="feedback-message"
            rows={5}
            value={message}
            placeholder={t(`admin.feedback.placeholder.${kind}`)}
            onChange={(event) => setMessage(event.target.value)}
          />
        </Field>

        {bug && failed.length > 0 && (
          <Field orientation="horizontal" className="items-start">
            <Checkbox
              id="feedback-failed"
              checked={includeFailed}
              onCheckedChange={(checked) => setIncludeFailed(checked === true)}
            />
            <div className="flex min-w-0 flex-col gap-1">
              <FieldLabel htmlFor="feedback-failed">
                {t('admin.feedback.failed_requests', { count: failed.length })}
              </FieldLabel>
              <p className="text-muted-foreground text-xs">
                {t('admin.feedback.failed_requests_hint')}
              </p>
              <pre className="overflow-x-auto rounded-md bg-muted p-2 text-xs">
                {failedRequestLines(failed)}
              </pre>
            </div>
          </Field>
        )}

        {bug &&
          (diagnostics.isLoading ? (
            <Skeleton className="h-5 w-full" />
          ) : report ? (
            <p className="text-muted-foreground text-xs">
              {t('admin.feedback.system_info_included')}{' '}
              <Link
                to="/$storeId/settings/system-info"
                params={{ storeId }}
                onClick={onClose}
                className="underline underline-offset-2"
              >
                {t('admin.feedback.review_system_info')}
              </Link>
            </p>
          ) : (
            <p className="text-muted-foreground text-xs">
              {t('admin.feedback.system_info_unavailable')}
            </p>
          ))}
      </DialogBody>
      <DialogFooter>
        <Button disabled={!input.message || diagnostics.isLoading} onClick={openOnGitHub}>
          <ExternalLinkIcon />
          {t(bug ? 'admin.feedback.open_issue' : 'admin.feedback.open_discussion')}
        </Button>
      </DialogFooter>
    </>
  )
}
