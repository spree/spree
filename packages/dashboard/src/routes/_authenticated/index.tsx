import { useAuth } from '@spree/dashboard-core'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { AuthShell } from '../../components/spree/auth-shell'
import { NoStoreAccess } from '../../components/spree/no-store-access'

export const Route = createFileRoute('/_authenticated/')({
  component: IndexRedirect,
})

function IndexRedirect() {
  const { user, logout } = useAuth()
  if (!user) return null

  const firstStoreId = user.stores[0]?.id
  if (firstStoreId) {
    return <Navigate to="/$storeId" params={{ storeId: firstStoreId }} replace />
  }

  return (
    <AuthShell>
      <NoStoreAccess user={user} signOut={logout} />
    </AuthShell>
  )
}
