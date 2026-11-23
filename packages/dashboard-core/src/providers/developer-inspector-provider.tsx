import { toastManager } from '@spree/dashboard-ui'
import { useHotkey } from '@tanstack/react-hotkeys'
import {
  createContext,
  lazy,
  type ReactNode,
  Suspense,
  useContext,
  useEffect,
  useMemo,
  useState,
  useSyncExternalStore,
} from 'react'
import { useTranslation } from 'react-i18next'
import {
  getDeveloperInspectorEntries,
  subscribeDeveloperInspector,
} from '../lib/developer-inspector'

// Developer-only, so the drawer and its JSON viewer ship in their own chunk,
// fetched the first time an admin opens it.
const DeveloperInspectorDrawer = lazy(() =>
  import('../components/developer-inspector-drawer').then((m) => ({
    default: m.DeveloperInspectorDrawer,
  })),
)

export const DEVELOPER_INSPECTOR_HOTKEY = 'Mod+Shift+D'

interface DeveloperInspectorState {
  open: boolean
  setOpen: (open: boolean) => void
  /** Opens the panel's feedback dialog, when it has one; `'bug'` opens it on a bug report. */
  sendFeedback?: (kind?: 'bug') => void
}

const DeveloperInspectorContext = createContext<DeveloperInspectorState | null>(null)

/**
 * The developer inspector: the admin client's recent requests in a bottom
 * drawer, for debugging an integration or filing an issue. Opened from the
 * account menu or the keyboard shortcut.
 *
 * Records only what `adminClient` sends, so a panel built on another client
 * mounts it to no effect.
 */
export function DeveloperInspectorProvider({
  children,
  systemInfoPath,
  onSendFeedback,
}: {
  children: ReactNode
  /**
   * Offered in the account menu, the drawer and on a server error, when the
   * panel takes feedback.
   */
  onSendFeedback?: (kind?: 'bug') => void
  /** Linked from the drawer header, when the panel has a system info page. */
  systemInfoPath?: string
}) {
  const [open, setOpen] = useState(false)
  // Latches on first open so the lazy chunk loads only for admins who use it,
  // and the drawer keeps its state between openings.
  const [mounted, setMounted] = useState(false)

  const value = useMemo<DeveloperInspectorState>(
    () => ({
      open,
      setOpen: (next) => {
        if (next) setMounted(true)
        setOpen(next)
      },
      sendFeedback: onSendFeedback,
    }),
    [open, onSendFeedback],
  )

  useServerErrorToast(onSendFeedback)

  useHotkey(DEVELOPER_INSPECTOR_HOTKEY, () => value.setOpen(!open))

  return (
    <DeveloperInspectorContext.Provider value={value}>
      {children}
      {mounted && (
        <Suspense fallback={null}>
          <DeveloperInspectorDrawer
            open={value.open}
            onOpenChange={value.setOpen}
            systemInfoPath={systemInfoPath}
          />
        </Suspense>
      )}
    </DeveloperInspectorContext.Provider>
  )
}

// One toast for a burst of failures: a failed query is retried, and a page
// often fires several requests that fail for the same reason.
const SERVER_ERROR_TOAST_INTERVAL_MS = 10_000

/**
 * Offers to report a bug when the Admin API answers with a 5xx: that is a
 * bug in Spree or the installation, not something the admin did wrong.
 */
function useServerErrorToast(sendFeedback?: (kind?: 'bug') => void) {
  const { t } = useTranslation()

  useEffect(() => {
    if (!sendFeedback) return
    let seen = getDeveloperInspectorEntries()[0]?.id ?? 0
    let toastedAt = 0

    return subscribeDeveloperInspector(() => {
      const entries = getDeveloperInspectorEntries()
      const fresh = entries.filter((entry) => entry.id > seen)
      seen = entries[0]?.id ?? seen
      const failure = fresh.find((entry) => entry.status !== null && entry.status >= 500)
      if (!failure || Date.now() - toastedAt < SERVER_ERROR_TOAST_INTERVAL_MS) return

      toastedAt = Date.now()
      toastManager.add({
        type: 'error',
        title: t('admin.components.server_error.title'),
        description: failure.requestId
          ? t('admin.components.server_error.request_id', { id: failure.requestId })
          : undefined,
        actionProps: {
          children: t('admin.components.server_error.report'),
          onClick: () => sendFeedback('bug'),
        },
      })
    })
  }, [sendFeedback, t])
}

/** The inspector's state when a provider is mounted, `null` otherwise. */
export function useOptionalDeveloperInspector(): DeveloperInspectorState | null {
  return useContext(DeveloperInspectorContext)
}

/** The recorded requests, newest first. */
export function useDeveloperInspectorEntries() {
  return useSyncExternalStore(subscribeDeveloperInspector, getDeveloperInspectorEntries)
}
