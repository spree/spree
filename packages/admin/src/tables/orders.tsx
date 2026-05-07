import { Link } from '@tanstack/react-router'
import { ShoppingCartIcon } from 'lucide-react'
import { RelativeTime } from '@/components/spree/relative-time'
import { StatusBadge } from '@/components/ui/badge'
import { defineTable } from '@/lib/table-registry'

defineTable('orders', {
  title: 'Orders',
  searchParam: 'multi_search',
  searchPlaceholder: 'Search orders...',
  defaultSort: { field: 'completed_at', direction: 'desc' },
  emptyIcon: <ShoppingCartIcon className="size-8 text-muted-foreground/50" />,
  emptyMessage: 'No orders found',
  columns: [
    {
      key: 'number',
      label: 'Number',
      sortable: true,
      filterable: true,
      default: true,
      render: (order) => (
        <Link
          to={'/$storeId/orders/$orderId' as string}
          params={{ orderId: order.id }}
          className="font-medium text-foreground no-underline"
        >
          #{order.number}
        </Link>
      ),
    },
    {
      key: 'completed_at',
      label: 'Date',
      sortable: true,
      default: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (order) => <RelativeTime iso={order.completed_at} />,
    },
    {
      key: 'email',
      label: 'Customer',
      sortable: true,
      filterable: true,
      default: true,
      className: 'text-sm',
      render: (order) => order.email ?? '—',
    },
    {
      key: 'payment_status',
      label: 'Payment',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'status',
      filterOptions: [
        { value: 'balance_due', label: 'Balance due' },
        { value: 'credit_owed', label: 'Credit owed' },
        { value: 'failed', label: 'Failed' },
        { value: 'paid', label: 'Paid' },
        { value: 'void', label: 'Void' },
      ],
      render: (order) =>
        order.payment_status ? <StatusBadge status={order.payment_status} /> : '—',
    },
    {
      key: 'fulfillment_status',
      label: 'Fulfillment',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'status',
      filterOptions: [
        { value: 'backorder', label: 'Backorder' },
        { value: 'canceled', label: 'Canceled' },
        { value: 'partial', label: 'Partial' },
        { value: 'pending', label: 'Pending' },
        { value: 'ready', label: 'Ready' },
        { value: 'fulfilled', label: 'Fulfilled' },
      ],
      render: (order) =>
        order.fulfillment_status ? <StatusBadge status={order.fulfillment_status} /> : '—',
    },
    {
      key: 'total_quantity',
      label: 'Items',
      sortable: true,
      default: true,
      className: 'text-right tabular-nums text-sm text-muted-foreground',
      render: (order) => {
        const count = order.total_quantity ?? 0
        return `${count} ${count === 1 ? 'item' : 'items'}`
      },
    },
    {
      key: 'total',
      label: 'Total',
      sortable: true,
      filterable: true,
      default: true,
      filterType: 'number',
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (order) => order.display_total ?? '—',
    },
    {
      key: 'status',
      label: 'Status',
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'status',
      filterOptions: [
        { value: 'draft', label: 'Draft' },
        { value: 'placed', label: 'Placed' },
        { value: 'canceled', label: 'Canceled' },
      ],
      render: (order) => <StatusBadge status={order.status} />,
    },
    {
      key: 'created_at',
      label: 'Created at',
      sortable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (order) => <RelativeTime iso={order.created_at} />,
    },
    {
      key: 'updated_at',
      label: 'Updated at',
      sortable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (order) => <RelativeTime iso={order.updated_at} />,
    },
    // Filter-only columns
    {
      key: 'first_name',
      label: 'First name',
      filterable: true,
      displayable: false,
      ransackAttribute: 'bill_address_firstname_i',
    },
    {
      key: 'last_name',
      label: 'Last name',
      filterable: true,
      displayable: false,
      ransackAttribute: 'bill_address_lastname',
    },
    {
      key: 'sku',
      label: 'SKU',
      filterable: true,
      displayable: false,
      ransackAttribute: 'line_items_variant_sku',
    },
  ],
})
