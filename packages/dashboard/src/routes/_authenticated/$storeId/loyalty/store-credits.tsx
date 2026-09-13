import type { StoreCredit, StoreCreditCurrencyTotal } from '@spree/admin-sdk'
import { PageHeader, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  cn,
  Pagination,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { useIsFetching } from '@tanstack/react-query'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  listStoreCredits,
  useStoreCredit,
  useStoreCreditEvents,
} from '../../../../hooks/use-store-credits'
import { erasedFieldValue } from '../../../../lib/erased-customer'
import { originLabel } from '../../../../tables/store-credits'

const storeCreditsSearchSchema = resourceSearchSchema.extend({
  credit: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/loyalty/store-credits')({
  validateSearch: storeCreditsSearchSchema,
  component: StoreCreditsPage,
})

// The customer chip on every row and the issuer in the sheet both need their
// association inlined, so the list is self-sufficient without a fetch per row.
const LIST_EXPAND = ['customer', 'created_by']

/**
 * What the store owes in prepaid balances, across every customer.
 *
 * Read-only: a credit belongs to one customer and is issued, edited and
 * deleted on that customer's profile. This page answers how much is owed, to
 * whom, and why.
 */
function StoreCreditsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const navigate = useNavigate()
  // Mirrored from the list response rather than fetched separately, so the
  // cards always describe the same filtered set as the rows. `queryFn` only
  // runs on an actual fetch, so the last totals are kept across a cached
  // render instead of blanking the cards until a refetch lands.
  const [totals, setTotals] = useState<StoreCreditCurrencyTotal[]>([])
  // The cards trail the rows: `queryFn` sets them, so during a refetch they
  // still describe the previous filter. Dimming them says "these are being
  // recalculated" rather than passing stale figures off as the current ones.
  const refetching = useIsFetching({ queryKey: ['store-credits'] }) > 0

  const openCredit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, credit: id }) as never })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { credit: _credit, ...rest } = prev
        return rest as never
      },
    })

  useRowClickBridge('data-store-credit-id', openCredit)

  return (
    <>
      <div className="flex flex-col gap-6">
        <PageHeader
          title={t('admin.nav.store_credits')}
          subtitle={t('admin.store_credits.page.subtitle')}
          sticky={false}
        />

        <OutstandingTotals totals={totals} stale={refetching} />

        <ResourceTable<StoreCredit>
          tableKey="store-credits"
          queryKey="store-credits"
          queryFn={async (params) => {
            const response = await listStoreCredits(params)
            setTotals(response.meta.totals ?? [])
            return response
          }}
          searchParams={search}
          defaultParams={{ expand: LIST_EXPAND }}
          // The page mounts its own header so the totals can sit between the
          // title and the list; without this the table renders a second one.
          hideHeader
        />
      </div>

      {search.credit && (
        // Keyed by the credit so a deep link from one credit to another
        // remounts the sheet rather than showing the previous ledger page.
        <StoreCreditSheet
          key={search.credit}
          id={search.credit}
          onOpenChange={(open) => !open && closeSheet()}
        />
      )}
    </>
  )
}

/**
 * The store's liability, one card per currency. Reads the totals the list
 * returned, so filtering by a customer turns these into that customer's
 * balance.
 */
function OutstandingTotals({
  totals,
  stale = false,
}: {
  totals: StoreCreditCurrencyTotal[]
  stale?: boolean
}) {
  const { t } = useTranslation()

  if (totals.length === 0) return null

  return (
    <div
      className={cn(
        'grid gap-4 transition-opacity sm:grid-cols-2 lg:grid-cols-3',
        stale && 'opacity-50',
      )}
      aria-busy={stale || undefined}
    >
      {totals.map((total) => (
        <Card key={total.currency}>
          <CardContent className="flex flex-col gap-1 p-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">
                {t('admin.store_credits.totals.outstanding')}
              </span>
              <Badge variant="outline">{total.currency}</Badge>
            </div>
            <span className="font-semibold text-2xl tabular-nums">
              {total.display_amount_remaining}
            </span>
            <div className="flex gap-4 text-muted-foreground text-xs tabular-nums">
              <span>
                {t('admin.store_credits.totals.issued')} {total.display_amount}
              </span>
              <span>
                {t('admin.store_credits.totals.used')} {total.display_amount_used}
              </span>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

/**
 * The credit's details and its ledger. Read-only — editing a credit happens
 * on the customer profile, which the footer links to.
 */
function StoreCreditSheet({
  id,
  onOpenChange,
}: {
  id: string
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const [ledgerPage, setLedgerPage] = useState(1)
  const { data: credit, isLoading } = useStoreCredit(id, ['customer', 'created_by'])
  const { data: events, isLoading: eventsLoading } = useStoreCreditEvents(id, ledgerPage)

  const customerLabel = credit?.customer
    ? erasedFieldValue(credit.customer.email, credit.customer.anonymized)
    : t('admin.store_credits.no_customer')

  return (
    <Sheet open onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{isLoading ? <Skeleton className="h-6 w-40" /> : customerLabel}</SheetTitle>
          <SheetDescription>{t('admin.store_credits.sheet.description')}</SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto p-4">
          {isLoading || !credit ? (
            <Skeleton className="h-40 w-full" />
          ) : (
            <>
              <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                <DetailRow
                  label={t('admin.fields.store_credit.amount.label')}
                  value={credit.display_amount}
                  numeric
                />
                <DetailRow
                  label={t('admin.store_credits.columns.used')}
                  value={credit.display_amount_used}
                  numeric
                />
                <DetailRow
                  label={t('admin.store_credits.columns.authorized')}
                  value={credit.display_amount_authorized}
                  numeric
                />
                <DetailRow
                  label={t('admin.store_credits.columns.remaining')}
                  value={credit.display_amount_remaining}
                  numeric
                  emphasis
                />
                <DetailRow
                  label={t('admin.fields.store_credit.currency.label')}
                  value={credit.currency}
                />
                <DetailRow
                  label={t('admin.store_credits.columns.origin')}
                  value={originLabel(credit.originator_type)}
                />
                <DetailRow
                  label={t('admin.store_credits.columns.issued_by')}
                  value={credit.created_by?.email ?? '—'}
                />
                <DetailRow
                  label={t('admin.fields.store_credit.memo.label')}
                  value={credit.memo ?? '—'}
                />
              </dl>

              <div className="flex flex-col gap-2">
                <h3 className="font-medium text-sm">{t('admin.store_credits.ledger.title')}</h3>
                {eventsLoading ? (
                  <Skeleton className="h-20 w-full" />
                ) : events?.data.length ? (
                  <>
                    <ul className="flex flex-col divide-y rounded-md border">
                      {events.data.map((event) => (
                        <li
                          key={event.id}
                          className="flex items-baseline justify-between gap-3 p-3"
                        >
                          <span className="text-sm">{event.display_action ?? event.action}</span>
                          <span className="flex items-baseline gap-3">
                            <span className="text-sm tabular-nums">{event.display_amount}</span>
                            <time
                              className="whitespace-nowrap text-muted-foreground text-xs"
                              dateTime={event.created_at}
                            >
                              {new Date(event.created_at).toLocaleDateString()}
                            </time>
                          </span>
                        </li>
                      ))}
                    </ul>
                    {events.meta && <Pagination meta={events.meta} onPageChange={setLedgerPage} />}
                  </>
                ) : (
                  <p className="text-muted-foreground text-sm">
                    {t('admin.store_credits.ledger.empty')}
                  </p>
                )}
              </div>
            </>
          )}
        </div>

        <SheetFooter>
          {credit?.customer_id && (
            <Button asChild variant="outline">
              <Link
                to={'/$storeId/customers/$customerId' as string}
                params={{ customerId: credit.customer_id }}
              >
                {t('admin.store_credits.sheet.open_customer')}
              </Link>
            </Button>
          )}
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

/** One label/value pair in the credit's detail list. */
function DetailRow({
  label,
  value,
  numeric = false,
  emphasis = false,
}: {
  label: string
  value: string
  numeric?: boolean
  emphasis?: boolean
}) {
  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd
        className={cn(
          'text-right',
          numeric && 'tabular-nums',
          emphasis && 'font-medium text-foreground',
        )}
      >
        {value}
      </dd>
    </>
  )
}
