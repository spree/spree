import { CatchBoundary } from '@tanstack/react-router'
import { type ComponentType, lazy, type ReactNode, Suspense, useState } from 'react'
import { reportCaughtError } from '../lib/error-reporting'

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
}

function lazyFrom<P extends object>(load: () => Promise<ComponentType<P>>) {
  return lazy(async () => ({ default: await load() }))
}

/**
 * Lazily loads a component that is not the page itself, such as a drawer or
 * a panel, so that a failed load costs that component alone. The page around
 * it keeps rendering, with any unsaved edits; the failure goes to
 * `reportCaughtError`, which reloads onto the current build when a deploy
 * removed the chunk; and the next `retryKey` loads it again. A bare
 * `React.lazy` remembers its failure for good, and its error replaces the
 * whole page with the error screen.
 *
 *     const loadDrawer = () => import('./drawer').then((m) => m.Drawer)
 *     <IsolatedLazy load={loadDrawer} retryKey={opens} props={{ open }} />
 */
export function IsolatedLazy<P extends object>({
  load,
  props,
  fallback = null,
  retryKey,
}: IsolatedLazyProps<P>) {
  const [attempt, setAttempt] = useState(() => ({
    Component: lazyFrom(load),
    failed: false,
    retryKey,
  }))
  if (attempt.failed && attempt.retryKey !== retryKey) {
    setAttempt({ Component: lazyFrom(load), failed: false, retryKey })
  }
  if (attempt.failed) return null

  const { Component } = attempt
  return (
    <CatchBoundary
      getResetKey={() => 0}
      errorComponent={() => null}
      onCatch={(error, errorInfo) => {
        setAttempt((current) => ({ ...current, failed: true, retryKey }))
        reportCaughtError(error, errorInfo)
      }}
    >
      <Suspense fallback={fallback}>
        <Component {...props} />
      </Suspense>
    </CatchBoundary>
  )
}
