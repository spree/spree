import { usePermissions } from '@spree/dashboard-core'
import { createFileRoute, Outlet, useParams } from '@tanstack/react-router'
import { useEffect } from 'react'
import { rememberSeller, setActiveSeller } from '../../api-client'
import { PanelChrome } from '../../panel-chrome'

export const Route = createFileRoute('/_authenticated/$sellerId')({
  component: SellerLayout,
})

/**
 * Everything below this route acts as one seller.
 *
 * The id in the URL is the single source of truth — the client header follows
 * it, so a seller can keep two sellers open in two tabs without one stealing
 * the other's session, and a bookmarked page opens the seller it belongs to.
 */
function SellerLayout() {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const { refresh: refreshPermissions } = usePermissions()

  // Synchronously, not in an effect: children render (and fetch) before
  // effects run, and a request sent under the previous seller's header would
  // load the wrong seller's data into this one's screen.
  setActiveSeller(sellerId)

  useEffect(() => {
    rememberSeller(sellerId)
  }, [sellerId])

  // Capability is per seller, so the permission provider's own fetch — which
  // runs the moment authentication succeeds, before any seller is chosen —
  // comes back with nothing and every `<Can>` and permission-gated nav entry
  // reads as denied. That is why the sidebar was empty until a refresh.
  //
  // Unlike the operator's dashboard, this does NOT skip its first run: there
  // the initial fetch is already correct for the initial store, here it never
  // is. Re-runs on `sellerId` so switching sellers reloads capability too.
  // biome-ignore lint/correctness/useExhaustiveDependencies: sellerId drives the seller-switch re-run
  useEffect(() => {
    void refreshPermissions()
  }, [sellerId, refreshPermissions])

  return (
    <PanelChrome>
      <Outlet />
    </PanelChrome>
  )
}
