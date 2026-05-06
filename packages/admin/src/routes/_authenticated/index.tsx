import { createFileRoute, redirect } from '@tanstack/react-router'
import { adminClient } from '@/client'

export const Route = createFileRoute('/_authenticated/')({
  beforeLoad: async ({ context }) => {
    // Wait for bootstrap; the parent _authenticated guard will redirect to /login
    // if we end up unauthenticated. Without this guard, we'd fire a /store request
    // with no token during cold load and trigger a refresh loop.
    if (context.auth.isInitializing || !context.auth.isAuthenticated) return

    // Fetch the current store to get its prefixed ID for the URL
    try {
      const store = await adminClient.store.get()
      throw redirect({ to: '/$storeId', params: { storeId: store.id } })
    } catch (e) {
      // If it's already a redirect, re-throw
      if (e instanceof Error && 'to' in e) throw e
      // Fallback: use 'default' as store ID
      throw redirect({ to: '/$storeId', params: { storeId: 'default' } })
    }
  },
})
