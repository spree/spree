import { Link } from '@tanstack/react-router'
import { UsersIcon } from 'lucide-react'
import { RelativeTime } from '@/components/spree/relative-time'
import { TagList } from '@/components/spree/tag-list'
import { ActiveBadge, Badge } from '@/components/ui/badge'
import { customerGroupAutocompleteProps } from '@/hooks/use-customer-groups'
import { defineTable } from '@/lib/table-registry'

defineTable('customers', {
  title: 'Customers',
  searchParam: 'search',
  searchPlaceholder: 'Search by email or name…',
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <UsersIcon className="size-8 text-muted-foreground" />,
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
      render: (c) => c.full_name ?? ([c.first_name, c.last_name].filter(Boolean).join(' ') || '—'),
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
      key: 'customer_groups',
      label: 'Groups',
      default: false,
      filterable: true,
      filterType: 'resource',
      // `users.customer_groups.id` join — backed by the
      // `customer_groups` whitelisted_ransackable_association on User.
      ransackAttribute: 'customer_groups_id',
      filterResource: customerGroupAutocompleteProps('customer-groups-picker'),
      render: (c) => {
        const groups = c.customer_groups ?? []
        if (groups.length === 0) return '—'
        return (
          <div className="flex flex-wrap gap-1">
            {groups.map((g: { id: string; name: string }) => (
              <Badge key={g.id} variant="secondary">
                {g.name}
              </Badge>
            ))}
          </div>
        )
      },
    },
    {
      key: 'tags',
      label: 'Tags',
      sortable: false,
      filterable: true,
      filterType: 'tags',
      taggableType: 'Spree::User',
      default: false,
      render: (c) => <TagList tags={c.tags} />,
    },
    {
      key: 'accepts_email_marketing',
      label: 'Newsletter',
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'boolean',
      render: (c) => <ActiveBadge active={c.accepts_email_marketing} />,
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
