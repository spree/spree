import type { GiftCard } from '@spree/admin-sdk'
import { GiftIcon } from 'lucide-react'
import { RelativeTime } from '@/components/spree/relative-time'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { Badge } from '@/components/ui/badge'
import { adminUserAutocompleteProps } from '@/hooks/use-admin-users'
import { customerAutocompleteProps } from '@/hooks/use-customers'
import { giftCardBatchAutocompleteProps } from '@/hooks/use-gift-cards'
import { defineTable } from '@/lib/table-registry'

// Server `Spree::GiftCard#display_state` exposes "expired" when the card
// is past its expiration date, even though the underlying column is still
// "active" — keep this list in sync with the state machine + display_state
// override in `app/models/spree/gift_card.rb`.
const STATUS_OPTIONS = [
  { value: 'active', label: 'Active' },
  { value: 'partially_redeemed', label: 'Partially redeemed' },
  { value: 'redeemed', label: 'Redeemed' },
  { value: 'canceled', label: 'Canceled' },
] as const

const STATUS_VARIANT: Record<
  string,
  'success' | 'destructive' | 'secondary' | 'default' | 'outline'
> = {
  active: 'success',
  partially_redeemed: 'default',
  redeemed: 'secondary',
  canceled: 'destructive',
  expired: 'destructive',
}

function formatStatus(value: string): string {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

defineTable<GiftCard>('gift-cards', {
  title: 'Gift Cards',
  searchParam: 'code_cont',
  searchPlaceholder: 'Search by code…',
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <GiftIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No gift cards yet',
  columns: [
    {
      key: 'code',
      label: 'Code',
      sortable: true,
      filterable: true,
      default: true,
      render: (g) => (
        <ResourceNameCell
          id={g.id}
          dataAttr="data-gift-card-id"
          name={g.code}
          secondary={g.customer?.email ?? undefined}
        />
      ),
    },
    {
      key: 'status',
      label: 'Status',
      // Ransack filters off the underlying `state` column — `display_state`
      // is a presentation-only override that returns 'expired' for active
      // cards past their `expires_at`. Server still indexes `state`.
      ransackAttribute: 'state',
      filterable: true,
      filterType: 'enum',
      // Spread to narrow the readonly type into ColumnDef's mutable shape.
      filterOptions: STATUS_OPTIONS.map(({ value, label }) => ({ value, label })),
      default: true,
      render: (g) => {
        const status = g.status ?? 'active'
        return <Badge variant={STATUS_VARIANT[status] ?? 'secondary'}>{formatStatus(status)}</Badge>
      },
    },
    {
      key: 'display_amount',
      label: 'Amount',
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (g) => g.display_amount,
    },
    {
      key: 'display_amount_used',
      label: 'Used',
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap',
      render: (g) => g.display_amount_used,
    },
    {
      key: 'display_amount_remaining',
      label: 'Remaining',
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap',
      render: (g) => g.display_amount_remaining,
    },
    {
      key: 'currency',
      label: 'Currency',
      sortable: true,
      filterable: true,
      filterType: 'currency',
      default: false,
      render: (g) => g.currency,
    },
    {
      key: 'gift_card_batch',
      label: 'Batch',
      // Filter narrows to cards belonging to one or more batches via the
      // `gift_card_batch_id_in` Ransack predicate (whitelisted on the
      // GiftCard model). Picker renders inline batch prefixes.
      ransackAttribute: 'gift_card_batch_id',
      filterable: true,
      filterType: 'resource',
      filterResource: giftCardBatchAutocompleteProps('gift-card-batch-picker'),
      default: false,
      render: (g) =>
        g.gift_card_batch ? (
          <Badge variant="outline">{g.gift_card_batch.prefix ?? g.gift_card_batch.id}</Badge>
        ) : (
          '—'
        ),
    },
    {
      key: 'customer',
      label: 'Customer',
      // Whitelisted `user_id` on the GiftCard model.
      ransackAttribute: 'user_id',
      filterable: true,
      filterType: 'resource',
      filterResource: customerAutocompleteProps('gift-card-customer-filter'),
      default: false,
      render: (g) => g.customer?.email ?? '—',
    },
    {
      key: 'created_by',
      label: 'Issued by',
      // GiftCard whitelists `code`, `user_id`, `state`, `gift_card_batch_id`.
      // `created_by_id` is not whitelisted yet — Ransack will reject the
      // predicate without it; we add it server-side alongside this column.
      ransackAttribute: 'created_by_id',
      filterable: true,
      filterType: 'resource',
      filterResource: adminUserAutocompleteProps('gift-card-created-by-filter'),
      default: false,
      render: (g) => g.created_by?.email ?? '—',
    },
    {
      key: 'expires_at',
      label: 'Expires',
      sortable: true,
      filterable: true,
      filterType: 'date',
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (g) => (g.expires_at ? <RelativeTime iso={g.expires_at} /> : '—'),
    },
    {
      key: 'created_at',
      label: 'Created',
      sortable: true,
      filterType: 'date',
      default: false,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (g) => <RelativeTime iso={g.created_at} />,
    },
  ],
})
