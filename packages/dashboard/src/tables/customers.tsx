import { defineTable, Subject } from '@spree/dashboard-core'
import {
  ActiveBadge,
  Avatar,
  AvatarFallback,
  Badge,
  RelativeTime,
  TagList,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { UsersIcon } from 'lucide-react'
import { customerGroupAutocompleteProps } from '@/hooks/use-customer-groups'

defineTable('customers', {
  title: i18n.t('admin.nav.customers'),
  searchParam: 'search',
  searchPlaceholder: i18n.t('admin.customers.table.search_placeholder'),
  defaultSort: { field: 'created_at', direction: 'desc' },
  emptyIcon: <UsersIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.customers.table.empty'),
  columns: [
    {
      key: 'email',
      label: i18n.t('admin.fields.email.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (c) => (
        <div className="flex items-center gap-2.5">
          <Avatar size="sm">
            <AvatarFallback seed={c.email} />
          </Avatar>
          <Link
            to={'/$storeId/customers/$customerId' as string}
            params={{ customerId: c.id }}
            className="font-medium text-foreground no-underline"
          >
            {c.email}
          </Link>
        </div>
      ),
    },
    {
      key: 'first_name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (c) => c.full_name ?? ([c.first_name, c.last_name].filter(Boolean).join(' ') || '—'),
    },
    {
      key: 'phone',
      label: i18n.t('admin.fields.phone.label'),
      sortable: true,
      filterable: true,
      default: false,
      render: (c) => c.phone ?? '—',
    },
    {
      key: 'orders_count',
      label: i18n.t('admin.customers.columns.orders'),
      default: true,
      className: 'text-right tabular-nums',
      render: (c) => c.orders_count ?? 0,
    },
    {
      key: 'total_spent',
      label: i18n.t('admin.customers.columns.total_spent'),
      default: true,
      className: 'text-right tabular-nums whitespace-nowrap font-medium',
      render: (c) => c.display_total_spent ?? '—',
    },
    {
      key: 'last_order_completed_at',
      label: i18n.t('admin.customers.columns.last_order'),
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (c) => <RelativeTime iso={c.last_order_completed_at} />,
    },
    {
      key: 'customer_groups',
      label: i18n.t('admin.customers.columns.groups'),
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
      label: i18n.t('admin.fields.customer.tags.label'),
      sortable: false,
      filterable: true,
      filterType: 'tags',
      taggableType: Subject.Customer,
      default: false,
      render: (c) => <TagList tags={c.tags} />,
    },
    {
      key: 'accepts_email_marketing',
      label: i18n.t('admin.customers.columns.newsletter'),
      sortable: true,
      filterable: true,
      default: false,
      filterType: 'boolean',
      render: (c) => <ActiveBadge active={c.accepts_email_marketing} />,
    },
  ],
})
