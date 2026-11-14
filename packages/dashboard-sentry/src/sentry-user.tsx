import { setTag, setUser } from '@sentry/react'
import { type AppRootSlotContext, useAuth } from '@spree/dashboard-core'
import { useLayoutEffect } from 'react'

/**
 * Tags events with the panel, attaches the signed-in user, and clears them
 * when the session ends. Renders nothing.
 */
export function SentryUser({ panel }: AppRootSlotContext) {
  const { user, isInitializing } = useAuth()
  const id = user?.id ?? null
  const email = user?.email ?? null

  useLayoutEffect(() => {
    setTag('panel', panel)
  }, [panel])

  useLayoutEffect(() => {
    // The session is still being restored from the refresh cookie.
    if (isInitializing) return
    setUser(id ? { id, email: email ?? undefined } : null)
  }, [id, email, isInitializing])

  return null
}
