import { Button, toastManager } from '@spree/dashboard-ui'
import { CatchBoundary } from '@tanstack/react-router'
import { type ComponentType, lazy, type ReactNode, Suspense, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { reportCaughtError } from '../lib/error-reporting'
import { isReloadingForStaleChunk } from '../lib/stale-chunk-recovery'

interface IsolatedLazyProps<P extends object> {
  /** Imports the component. Define it once at module level. */
  load: () => Promise<ComponentType<P>>
  /** The component's props. */
  props: P
  /** Shown while the component loads. Defaults to nothing. */
  fallback?: ReactNode
  /**
   * After a failed load, a new value loads the component again, for example
   * the count of times a drawer was opened.
   */
  retryKey?: unknown
  /**
   * How a failure is shown: a toast, for an overlay such as a drawer that has
   * no place on the page (the default), or a message with a retry button in
   * the component's place.
   */
  failure?: 'toast' | 'inline'
}

function lazyFrom<P extends object>(load: () => Promise<ComponentType<P>>) {
  return lazy(async () => ({ default: await load() }))
}

/**
 * Lazily loads a component that is not the page itself, such as a drawer or
 * a panel, so that a failed load costs that component alone. The page around
 * it keeps rendering, with any unsaved edits; the user is told it could not
 * load; the failure goes to `reportCaughtError`, which reloads onto the
 * current build when a deploy removed the chunk; and the next `retryKey`
 * loads it again. A bare `React.lazy` remembers its failure for good, and its
 * error replaces the whole page with the error screen.
 *
 *     const loadDrawer = () => import('./drawer').then((m) => m.Drawer)
 *     <IsolatedLazy load={loadDrawer} retryKey={opens} props={{ open }} />
 */
export function IsolatedLazy<P extends object>({
  load,
  props,
  fallback = null,
  retryKey,
  failure = 'toast',
}: IsolatedLazyProps<P>) {
  const { t } = useTranslation()
  const [attempt, setAttempt] = useState(() => ({
    Component: lazyFrom(load),
    failed: false,
    retryKey,
  }))
  const retry = () => setAttempt({ Component: lazyFrom(load), failed: false, retryKey })
  if (attempt.failed && attempt.retryKey !== retryKey) retry()

  if (attempt.failed) {
    if (failure === 'toast') return null
    return (
      <div className="flex flex-col items-start gap-2 text-sm" role="alert">
        <p className="text-muted-foreground">
          {t('admin.components.isolated_lazy.load_failed_description')}
        </p>
        <Button variant="outline" size="sm" onClick={retry}>
          {t('admin.components.error_state.retry')}
        </Button>
      </div>
    )
  }

  const { Component } = attempt
  return (
    <CatchBoundary
      getResetKey={() => 0}
      errorComponent={() => null}
      onCatch={(error, errorInfo) => {
        setAttempt((current) => ({ ...current, failed: true, retryKey }))
        reportCaughtError(error, errorInfo)
        // A reload onto the current build is under way; the page is leaving.
        if (failure === 'toast' && !isReloadingForStaleChunk()) {
          toastManager.add({
            type: 'error',
            title: t('admin.components.isolated_lazy.load_failed'),
            description: t('admin.components.isolated_lazy.load_failed_description'),
          })
        }
      }}
    >
      <Suspense fallback={fallback}>
        <Component {...props} />
      </Suspense>
    </CatchBoundary>
  )
}
