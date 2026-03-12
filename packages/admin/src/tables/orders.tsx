import { Link } from '@tanstack/react-router'
import { ShoppingCartIcon } from 'lucide-react'
import { StatusBadge } from '@/components/ui/badge'
import { formatRelativeTime } from '@/lib/formatters'
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
          to="/orders/$orderId"
          params={{ orderId: order.id }}
          className="font-medium text-zinc-950 no-underline"
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
      render: (order) => (order.completed_at ? formatRelativeTime(order.completed_at) : '—'),
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
      key: 'payment_state',
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
      render: (order) => (order.payment_state ? <StatusBadge status={order.payment_state} /> : '—'),
    },
    {
      key: 'shipment_state',
      label: 'Shipment',
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
        { value: 'shipped', label: 'Shipped' },
      ],
      render: (order) =>
        order.shipment_state ? <StatusBadge status={order.shipment_state} /> : '—',
    },
    {
      key: 'item_count',
      label: 'Items',
      sortable: true,
      default: true,
      className: 'text-right tabular-nums text-sm text-muted-foreground',
      render: (order) => {
        const count = order.item_count ?? 0
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
      key: 'state',
      label: 'State',
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'status',
      filterOptions: [
        { value: 'cart', label: 'Cart' },
        { value: 'address', label: 'Address' },
        { value: 'delivery', label: 'Delivery' },
        { value: 'payment', label: 'Payment' },
        { value: 'confirm', label: 'Confirm' },
        { value: 'complete', label: 'Complete' },
        { value: 'canceled', label: 'Canceled' },
        { value: 'returned', label: 'Returned' },
        { value: 'resumed', label: 'Resumed' },
      ],
      render: (order) => <StatusBadge status={order.state} />,
    },
    {
      key: 'created_at',
      label: 'Created at',
      sortable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (order) => formatRelativeTime(order.created_at),
    },
    {
      key: 'updated_at',
      label: 'Updated at',
      sortable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (order) => formatRelativeTime(order.updated_at),
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
