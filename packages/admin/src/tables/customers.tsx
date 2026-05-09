import { Link } from '@tanstack/react-router'
import { UsersIcon } from 'lucide-react'
import { RelativeTime } from '@/components/spree/relative-time'
import { defineTable } from '@/lib/table-registry'

defineTable('customers', {
  title: 'Customers',
  searchParam: 'search',
  searchPlaceholder: 'Search by email or name…',
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <UsersIcon className="size-8 text-muted-foreground/50" />,
  emptyMessage: 'No customers yet',
  columns: [
    {
      key: 'email',
      label: 'Email',
      sortable: true,
      filterable: true,
      default: true,
      render: (c) => (
        <Link
          to={'/$storeId/customers/$customerId' as string}
          params={{ customerId: c.id }}
          className="font-medium text-foreground no-underline"
        >
          {c.email}
        </Link>
      ),
    },
    {
      key: 'first_name',
      label: 'Name',
      sortable: true,
      filterable: true,
      default: true,
      render: (c) => {
        const name = [c.first_name, c.last_name].filter(Boolean).join(' ').trim()
        return name || '—'
      },
    },
    {
      key: 'phone',
      label: 'Phone',
      sortable: true,
      filterable: true,
      default: false,
      render: (c) => c.phone ?? '—',
    },
    {
      key: 'orders_count',
      label: 'Orders',
      default: true,
      className: 'text-right tabular-nums',
      render: (c) => c.orders_count ?? 0,
    },
    {
      key: 'total_spent',
      label: 'Total spent',
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (c) => c.display_total_spent ?? '—',
    },
    {
      key: 'last_order_completed_at',
      label: 'Last order',
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (c) => <RelativeTime iso={c.last_order_completed_at} />,
    },
    {
      key: 'accepts_email_marketing',
      label: 'Newsletter',
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'boolean',
      render: (c) => (c.accepts_email_marketing ? 'Yes' : 'No'),
    },
    {
      key: 'created_at',
      label: 'Created',
      sortable: true,
      default: false,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (c) => <RelativeTime iso={c.created_at} />,
    },
  ],
})
