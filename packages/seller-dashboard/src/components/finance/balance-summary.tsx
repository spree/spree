import { formatMoney, useMoneyLocale } from '@spree/dashboard-core'
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
 *
 * A position has two sides when the seller banks in a currency other than the
 * one they sold in: the balance is what their account will actually be paid,
 * and the sale's own figure is shown beneath it. Both are recorded figures.
 */
export function BalanceSummary({ balances }: { balances: Balance[] }) {
  const { t } = useTranslation()
  const locale = useMoneyLocale()

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
      {balances.map((balance) => {
        // Earned and pending are what the sales were worth; the rest is what
        // the account holds, in the currency it settles in.
        const sold = (amount: string) => formatMoney(amount, balance.currency, locale)
        const held = (amount: string) => formatMoney(amount, balance.settlement_currency, locale)
        return (
          <Card key={`${balance.currency}-${balance.settlement_currency}`}>
            <CardHeader>
              <CardTitle>
                {t('earnings.balance.owed', { currency: balance.settlement_currency })}
              </CardTitle>
              {balance.converted && (
                <CardDescription>
                  {t('earnings.balance.converted', { currency: balance.currency })}
                </CardDescription>
              )}
            </CardHeader>
            <CardContent className="flex flex-col gap-3">
              <span className="text-2xl font-semibold tabular-nums">{held(balance.balance)}</span>
              <dl className="flex flex-col gap-1 text-sm">
                <Figure label={t('earnings.balance.earned')} value={sold(balance.earned)} />
                {balance.converted && (
                  <Figure label={t('earnings.balance.payable')} value={held(balance.payable)} />
                )}
                <Figure label={t('earnings.balance.paid')} value={held(balance.paid)} />
                <Figure label={t('earnings.balance.pending')} value={sold(balance.pending)} />
              </dl>
            </CardContent>
          </Card>
        )
      })}
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
