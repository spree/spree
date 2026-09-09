import type { Seller } from '@spree/admin-sdk'
import { Card, CardContent, CardHeader, CardTitle, Separator } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useSellerBalances } from '../../../hooks/use-seller-ledger'
import { ReadRow } from './seller-read-row'

/**
 * What this seller has earned and what they are still owed, per currency.
 *
 * Nothing is ever converted between currencies, so a seller trading in two
 * has two positions rather than one total. Renders nothing until their first
 * fulfilled sale — an empty card on every new seller would only be noise.
 */
export function SellerBalanceCard({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const { data } = useSellerBalances(seller.id)

  const balances = data?.data ?? []
  if (balances.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.payouts.balance.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {balances.map((balance, index) => (
          <div key={balance.currency} className="flex flex-col gap-3">
            {index > 0 && <Separator />}
            <ReadRow label={t('admin.payouts.balance.owed', { currency: balance.currency })}>
              <span className="font-medium">{balance.display_balance}</span>
            </ReadRow>
            <ReadRow label={t('admin.payouts.balance.earned')}>{balance.display_earned}</ReadRow>
            <ReadRow label={t('admin.payouts.balance.paid')}>{balance.display_paid}</ReadRow>
            <ReadRow label={t('admin.payouts.balance.pending')}>{balance.display_pending}</ReadRow>
          </div>
        ))}

        <div className="flex gap-4 border-t pt-3 text-sm">
          <Link
            to={'/$storeId/sellers/transfers' as string}
            search={sellerFilter(seller.id, 'seller-transfers')}
          >
            {t('admin.nav.seller_transfers')}
          </Link>
          <Link
            to={'/$storeId/sellers/payouts' as string}
            search={sellerFilter(seller.id, 'seller-payouts')}
          >
            {t('admin.nav.seller_payouts')}
          </Link>
        </div>
      </CardContent>
    </Card>
  )
}

/**
 * Search params opening a ledger list filtered to one seller.
 *
 * JSON-encoded because that is how the resource table reads filters back off
 * the URL — the same shape `orderGroupSearch` builds for the orders list.
 */
function sellerFilter(sellerId: string, table: string): { filters: string } {
  return {
    filters: JSON.stringify([
      { id: `${table}-seller-${sellerId}`, field: 'seller_name', operator: 'eq', value: sellerId },
    ]),
  }
}
