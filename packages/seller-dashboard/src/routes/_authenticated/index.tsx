import { useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { rememberedSeller, sellerClient } from '../../api-client'
import { CenteredMessage } from '../../components/centered-message'
import { SellerPicker } from '../../pages/seller-picker'

export const Route = createFileRoute('/_authenticated/')({
  component: SellerEntry,
})

/**
 * Where a signed-in seller lands.
 *
 * Unlike the operator's dashboard, which always redirects into a store, a
 * seller may genuinely run several sellers — so the picker is a real page.
 * It is skipped in the two cases where the answer is already known: a
 * remembered choice from last session, or exactly one seller.
 */
function SellerEntry() {
  const { t } = useTranslation()
  const navigate = useNavigate()

  const { data, isLoading, error } = useQuery({
    queryKey: ['seller', 'me'],
    queryFn: () => sellerClient().me(),
  })

  const sellers = data?.sellers ?? []
  const remembered = rememberedSeller()
  // A remembered id is only honoured if the seller still runs that seller —
  // access can be revoked between sessions, and following a stale id would
  // land them on a page that 403s.
  const target =
    (remembered && sellers.some((seller) => seller.id === remembered) ? remembered : null) ??
    (sellers.length === 1 ? sellers[0].id : null)

  useEffect(() => {
    if (target) navigate({ to: '/$sellerId', params: { sellerId: target }, replace: true })
  }, [navigate, target])

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error) return <CenteredMessage>{t('common.error')}</CenteredMessage>
  if (target) return null

  return <SellerPicker />
}
