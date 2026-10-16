import type { UpdateStatus } from '@spree/admin-sdk'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogHeader,
  DialogTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { BellIcon, SparklesIcon } from '@spree/dashboard-ui/icons'
import { useState, useSyncExternalStore } from 'react'
import { useTranslation } from 'react-i18next'
import { useReleaseNotes } from '../../hooks/use-release-notes'
import { useUpdateStatus } from '../../hooks/use-update-status'
import { ReleaseNotes } from './release-notes'

// The newest release the admin has opened the notifications for, so the dot
// goes away once seen and comes back for the next release.
const SEEN_KEY = 'spree-notifications-seen'

function readSeen(): string | null {
  try {
    return window.localStorage.getItem(SEEN_KEY)
  } catch {
    return null
  }
}

// The bell is mounted twice, in the sidebar and in the phone's top bar, so
// both read one shared value: opening either clears the dot on both.
const seenListeners = new Set<() => void>()

function subscribeToSeen(listener: () => void) {
  seenListeners.add(listener)
  return () => {
    seenListeners.delete(listener)
  }
}

function markSeen(version: string) {
  try {
    window.localStorage.setItem(SEEN_KEY, version)
  } catch {
    // Storage blocked: the dot returns on the next visit.
  }
  for (const listener of seenListeners) listener()
}

/** The bell beside the account menu, and the notifications it opens. */
export function Notifications() {
  const { t } = useTranslation()
  const { data } = useUpdateStatus()
  const [open, setOpen] = useState(false)
  const seen = useSyncExternalStore(subscribeToSeen, readSeen, readSeen)

  const update = data?.update_available && data.latest_version ? data : null
  const unread = update !== null && seen !== update.latest_version

  function handleOpenChange(next: boolean) {
    setOpen(next)
    if (next && update?.latest_version) markSeen(update.latest_version)
  }

  return (
    <>
      <button
        type="button"
        onClick={() => handleOpenChange(true)}
        aria-label={unread ? t('admin.notifications.open_unread') : t('admin.notifications.open')}
        className="relative inline-flex size-9 shrink-0 items-center justify-center rounded-lg text-muted-foreground outline-hidden transition-colors duration-100 hover:bg-sidebar-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
      >
        <BellIcon className="size-5" />
        {unread && (
          <span
            aria-hidden="true"
            className="absolute top-1.5 right-1.5 size-2.5 rounded-full bg-blue-500 ring-2 ring-sidebar"
          />
        )}
      </button>
      <NotificationsDialog open={open} onOpenChange={handleOpenChange} update={update} />
    </>
  )
}

function NotificationsDialog({
  open,
  onOpenChange,
  update,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  update: UpdateStatus | null
}) {
  const { t } = useTranslation()

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{t('admin.notifications.title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="max-h-[70vh] overflow-y-auto">
          {update ? (
            <UpdateNotification update={update} open={open} />
          ) : (
            <p className="py-6 text-center text-muted-foreground text-sm">
              {t('admin.notifications.empty')}
            </p>
          )}
        </DialogBody>
      </DialogContent>
    </Dialog>
  )
}

function UpdateNotification({ update, open }: { update: UpdateStatus; open: boolean }) {
  const { t } = useTranslation()
  const notes = useReleaseNotes(update.latest_version, open)

  return (
    <article className="flex flex-col gap-4">
      <header className="flex items-start gap-3">
        <SparklesIcon className="mt-0.5 size-5 shrink-0 text-blue-600 dark:text-blue-400" />
        <div className="min-w-0 flex-1">
          <h3 className="font-semibold text-base">
            {t('admin.updates.available', { version: update.latest_version })}
          </h3>
          <p className="text-muted-foreground text-sm">
            {t('admin.updates.running', { version: update.current_version })}
          </p>
        </div>
        {update.latest_release_url && (
          <a
            href={update.latest_release_url}
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 font-medium text-sm underline underline-offset-3"
          >
            {t('admin.notifications.view_on_github')}
          </a>
        )}
      </header>
      <section className="border-t pt-4">
        {notes.isPending ? (
          <div className="flex flex-col gap-2">
            <Skeleton className="h-5 w-1/2" />
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-5/6" />
          </div>
        ) : notes.isError ? (
          <p className="text-muted-foreground text-sm">
            {t('admin.notifications.release_notes_unavailable')}
          </p>
        ) : notes.data ? (
          <ReleaseNotes markdown={notes.data} />
        ) : null}
      </section>
    </article>
  )
}
