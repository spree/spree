import type { StoreCredit, StoreCreditCurrencyTotal } from '@spree/admin-sdk'
import { isZeroMoney } from '@spree/admin-sdk'
import {
  Can,
  PageHeader,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  useMoneyLocale,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  cn,
  Pagination,
  RelativeTime,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PencilIcon, PlusIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import { useIsFetching } from '@tanstack/react-query'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { Money } from '../../../../components/spree/money'
import { EditStoreCreditDialog } from '../../../../components/spree/store-credits/edit-store-credit-dialog'
import { IssueStoreCreditDialog } from '../../../../components/spree/store-credits/issue-store-credit-dialog'
import { useDeleteCustomerStoreCredit } from '../../../../hooks/use-customer-store-credits'
import {
  listStoreCredits,
  useStoreCredit,
  useStoreCreditEvents,
} from '../../../../hooks/use-store-credits'
import { erasedFieldValue } from '../../../../lib/erased-customer'
import { formatAmount } from '../../../../lib/format-amount'
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
 * What the store owes in prepaid balances, across every customer, and where a
 * credit can be issued, edited or deleted. This page answers how much is owed,
 * to whom, and why.
 */
function StoreCreditsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const [issueOpen, setIssueOpen] = useState(false)
  const [editing, setEditing] = useState<StoreCredit | null>(null)
  const { canEdit, canDelete, deleteCredit, deletePending } = useStoreCreditActions()
  // Mirrored from the list response rather than fetched separately, so the
  // cards always describe the same filtered set as the rows. `queryFn` only
  // runs on an actual fetch, so the last totals are kept across a cached
  // render instead of blanking the cards until a refetch lands.
  const [totals, setTotals] = useState<StoreCreditCurrencyTotal[]>([])
  // The cards trail the rows: `queryFn` sets them, so during a refetch they
  // still describe the previous filter. Dimming them says "these are being
  // recalculated" rather than passing stale figures off as the current ones.
  const refetching = useIsFetching({ queryKey: ['store-credits'] }) > 0
  // Two filter changes in quick succession can resolve out of order. Without a
  // sequence the slower, older response would land last and leave the cards
  // describing a filter the table is no longer showing.
  const latestRequest = useRef(0)

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

  async function handleDelete(credit: StoreCredit) {
    const deleted = await deleteCredit(credit)
    if (deleted && credit.id === search.credit) closeSheet()
  }

  return (
    <>
      <div className="flex flex-col gap-6">
        <PageHeader
          title={t('admin.nav.store_credits')}
          description={t('admin.store_credits.page.subtitle')}
          docsPath="loyalty/store-credits-list"
          sticky={false}
          actions={
            <Can I="create" a={Subject.StoreCredit}>
              <Button onClick={() => setIssueOpen(true)}>
                <PlusIcon className="size-4" />
                {t('admin.pages.customers.detail.issue_credit')}
              </Button>
            </Can>
          }
        />

        <OutstandingTotals totals={totals} stale={refetching} />

        <ResourceTable<StoreCredit>
          tableKey="store-credits"
          queryKey="store-credits"
          queryFn={async (params) => {
            const request = ++latestRequest.current
            const response = await listStoreCredits(params)
            if (request === latestRequest.current) setTotals(response.meta.totals ?? [])
            return response
          }}
          searchParams={search}
          defaultParams={{ expand: LIST_EXPAND }}
          rowActions={(credit) => (
            <RowActions
              actions={[
                {
                  key: 'edit',
                  visible: canEdit(credit),
                  onSelect: () => setEditing(credit),
                },
                {
                  key: 'delete',
                  destructive: true,
                  visible: canDelete(credit),
                  disabled: deletePending,
                  onSelect: () => handleDelete(credit),
                },
              ]}
            />
          )}
          // The page mounts its own header so the totals can sit between the
          // title and the list; without this the table renders a second one.
          hideHeader
        />
      </div>

      <IssueStoreCreditDialog
        open={issueOpen}
        onOpenChange={setIssueOpen}
        onIssued={(credit) => openCredit(credit.id)}
      />

      {search.credit && (
        // Keyed by the credit so a deep link from one credit to another
        // remounts the sheet rather than showing the previous ledger page.
        <StoreCreditSheet
          key={search.credit}
          id={search.credit}
          onOpenChange={(open) => !open && closeSheet()}
          canEdit={canEdit}
          canDelete={canDelete}
          deletePending={deletePending}
          onEdit={setEditing}
          onDelete={handleDelete}
        />
      )}

      {editing?.customer_id && (
        <EditStoreCreditDialog
          customerId={editing.customer_id}
          credit={editing}
          onOpenChange={(open) => !open && setEditing(null)}
        />
      )}
    </>
  )
}

/**
 * Edit and delete go through the customer that holds the credit, so a credit
 * without one offers neither. A credit with any of its balance used can no
 * longer be deleted; the server refuses it, so the action is not offered.
 */
function useStoreCreditActions() {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteCustomerStoreCredit()

  const canEdit = (credit: StoreCredit) =>
    !!credit.customer_id && permissions.can('update', Subject.StoreCredit)

  const canDelete = (credit: StoreCredit) =>
    !!credit.customer_id &&
    isZeroMoney(credit.amount_used) &&
    permissions.can('destroy', Subject.StoreCredit)

  /** Resolves to whether the credit was deleted, so a cancel keeps the panel open. */
  async function deleteCredit(credit: StoreCredit) {
    if (!credit.customer_id) return false
    const ok = await confirm({
      message: t('admin.customers.detail.store_credit.delete_confirm_message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return false
    return deleteMutation.mutateAsync({ customerId: credit.customer_id, id: credit.id }).then(
      () => true,
      () => false,
    )
  }

  return { canEdit, canDelete, deleteCredit, deletePending: deleteMutation.isPending }
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
              <Money amount={total.amount_remaining} currency={total.currency} />
            </span>
            <div className="flex gap-4 text-muted-foreground text-xs tabular-nums">
              <span>
                {t('admin.store_credits.totals.issued')}{' '}
                <Money amount={total.amount} currency={total.currency} />
              </span>
              <span>
                {t('admin.store_credits.totals.used')}{' '}
                <Money amount={total.amount_used} currency={total.currency} />
              </span>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

/** The credit's details and its ledger. */
function StoreCreditSheet({
  id,
  onOpenChange,
  canEdit,
  canDelete,
  deletePending,
  onEdit,
  onDelete,
}: {
  id: string
  onOpenChange: (open: boolean) => void
  canEdit: (credit: StoreCredit) => boolean
  canDelete: (credit: StoreCredit) => boolean
  deletePending: boolean
  onEdit: (credit: StoreCredit) => void
  onDelete: (credit: StoreCredit) => void
}) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const [ledgerPage, setLedgerPage] = useState(1)
  const { data: credit, isLoading, isError } = useStoreCredit(id, ['customer', 'created_by'])
  const {
    data: events,
    isLoading: eventsLoading,
    isError: eventsError,
  } = useStoreCreditEvents(id, ledgerPage)

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
          {/* A failed request is not a slow one: leaving the skeleton up would
              tell the merchant the panel is still loading, forever. */}
          {isError ? (
            <p className="py-8 text-center text-destructive">
              {t('admin.store_credits.sheet.load_failed')}
            </p>
          ) : isLoading || !credit ? (
            <Skeleton className="h-40 w-full" />
          ) : (
            <>
              <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                <DetailRow
                  label={t('admin.fields.store_credit.amount.label')}
                  value={formatAmount(credit.amount, credit.currency, moneyLocale)}
                  numeric
                />
                <DetailRow
                  label={t('admin.store_credits.columns.used')}
                  value={formatAmount(credit.amount_used, credit.currency, moneyLocale)}
                  numeric
                />
                <DetailRow
                  label={t('admin.store_credits.columns.authorized')}
                  value={formatAmount(credit.amount_authorized, credit.currency, moneyLocale)}
                  numeric
                />
                <DetailRow
                  label={t('admin.store_credits.columns.remaining')}
                  value={formatAmount(credit.amount_remaining, credit.currency, moneyLocale)}
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
                {eventsError ? (
                  // Never "no movements" over an error — that would claim the
                  // balance never moved.
                  <p className="text-destructive text-sm">
                    {t('admin.store_credits.ledger.load_failed')}
                  </p>
                ) : eventsLoading ? (
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
                            <span className="text-sm tabular-nums">
                              <Money amount={event.amount} currency={credit.currency} />
                            </span>
                            <span className="whitespace-nowrap text-muted-foreground text-xs">
                              <RelativeTime iso={event.created_at} />
                            </span>
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
          {credit && canDelete(credit) && (
            <Button
              variant="destructive"
              className="mr-auto"
              disabled={deletePending}
              onClick={() => onDelete(credit)}
            >
              <TrashIcon className="size-4" />
              {t('admin.actions.delete')}
            </Button>
          )}
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
          {credit && canEdit(credit) && (
            <Button onClick={() => onEdit(credit)}>
              <PencilIcon className="size-4" />
              {t('admin.actions.edit')}
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
