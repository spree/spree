import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@spree/dashboard-ui'
import type { Balance } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'

/**
 * What the marketplace owes this seller, one card per currency.
 *
 * Nothing is ever converted between currencies, so two currencies are two
 * positions rather than one total. `pending` is money the payout provider has
 * not confirmed yet — shown beside the balance so a seller who has shipped
 * does not read their own order as unpaid.
 */
export function BalanceSummary({ balances }: { balances: Balance[] }) {
  const { t } = useTranslation()

  if (balances.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>{t('earnings.balance.title')}</CardTitle>
          <CardDescription>{t('earnings.balance.empty')}</CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {balances.map((balance) => (
        <Card key={balance.currency}>
          <CardHeader>
            <CardTitle>{t('earnings.balance.owed', { currency: balance.currency })}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            <span className="text-2xl font-semibold tabular-nums">{balance.display_balance}</span>
            <dl className="flex flex-col gap-1 text-sm">
              <Figure label={t('earnings.balance.earned')} value={balance.display_earned} />
              <Figure label={t('earnings.balance.paid')} value={balance.display_paid} />
              <Figure label={t('earnings.balance.pending')} value={balance.display_pending} />
            </dl>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

function Figure({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="tabular-nums">{value}</dd>
    </div>
  )
}
