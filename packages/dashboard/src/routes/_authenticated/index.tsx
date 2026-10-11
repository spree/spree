import {
  Slot,
  STORE_SELECTION_SLOT,
  type StoreSelectionSlotContext,
  useAuth,
} from '@spree/dashboard-core'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { AuthShell } from '../../components/spree/auth-shell'
import { NoStoreAccess } from '../../components/spree/no-store-access'

export const Route = createFileRoute('/_authenticated/')({
  component: StoreSelection,
})

function StoreSelection() {
  const { user, logout } = useAuth()
  if (!user) return null

  const context = { user, signOut: logout }
  return (
    <Slot<StoreSelectionSlotContext>
      name={STORE_SELECTION_SLOT}
      context={context}
      fallback={<FirstStoreRedirect {...context} />}
    />
  )
}

function FirstStoreRedirect(context: StoreSelectionSlotContext) {
  const firstStoreId = context.user.stores[0]?.id
  if (firstStoreId) {
    return <Navigate to="/$storeId" params={{ storeId: firstStoreId }} replace />
  }

  return (
    <AuthShell>
      <NoStoreAccess {...context} />
    </AuthShell>
  )
}
