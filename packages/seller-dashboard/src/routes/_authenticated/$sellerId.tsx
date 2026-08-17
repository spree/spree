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

  // Synchronously, not in an effect: children render (and fetch) before
  // effects run, and a request sent under the previous seller's header would
  // load the wrong seller's data into this one's screen.
  setActiveSeller(sellerId)

  useEffect(() => {
    rememberSeller(sellerId)
  }, [sellerId])

  return (
    <PanelChrome>
      <Outlet />
    </PanelChrome>
  )
}
