import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { adminClient } from '@/client'

export const Route = createFileRoute('/_authenticated/')({
  component: IndexRedirect,
})

function IndexRedirect() {
  const navigate = useNavigate()

  useEffect(() => {
    let cancelled = false
    adminClient.store
      .get()
      .then((store) => {
        if (!cancelled) navigate({ to: '/$storeId', params: { storeId: store.id }, replace: true })
      })
      .catch(() => {
        if (!cancelled) navigate({ to: '/$storeId', params: { storeId: 'default' }, replace: true })
      })
    return () => {
      cancelled = true
    }
  }, [navigate])

  return null
}
