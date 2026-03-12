import { createFileRoute, Outlet } from '@tanstack/react-router'
import { useEffect } from 'react'
import { adminClient } from '@/client'
import { StoreProvider } from '@/providers/store-provider'

export const Route = createFileRoute('/_authenticated/$storeId')({
  component: StoreLayout,
})

function StoreLayout() {
  const { storeId } = Route.useParams()

  useEffect(() => {
    adminClient.setStore(storeId)
  }, [storeId])

  return (
    <StoreProvider storeId={storeId}>
      <Outlet />
    </StoreProvider>
  )
}
