import { adminClient, useAuth } from '@spree/dashboard-core'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'

export const Route = createFileRoute('/_authenticated/')({
  component: IndexRedirect,
})

function IndexRedirect() {
  const navigate = useNavigate()
  const { user } = useAuth()

  // The authenticated user's stores list is the source of the initial store —
  // no request needed. The header-less `store.get()` fallback covers sessions
  // whose cached user predates the stores field; it resolves the default
  // store server-side.
  useEffect(() => {
    const firstStoreId = user?.stores?.[0]?.id
    if (firstStoreId) {
      navigate({ to: '/$storeId', params: { storeId: firstStoreId }, replace: true })
      return
    }

    let cancelled = false
    adminClient.store.get().then((store) => {
      if (!cancelled) navigate({ to: '/$storeId', params: { storeId: store.id }, replace: true })
    })
    return () => {
      cancelled = true
    }
  }, [navigate, user])

  return null
}
