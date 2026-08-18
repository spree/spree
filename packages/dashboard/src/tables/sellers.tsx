import type { Seller } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, StatusBadge } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { StoreIcon } from 'lucide-react'
import { SELLER_STATUSES } from '../schemas/seller'

defineTable<Seller>('sellers', {
  title: i18n.t('admin.nav.sellers'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.sellers.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <StoreIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.sellers.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (seller) => (
        <Link
          to={'/$storeId/sellers/$sellerId' as string}
          params={{ sellerId: seller.id }}
          className="font-medium text-foreground no-underline"
        >
          {seller.name}
        </Link>
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: SELLER_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`admin.sellers.status.${status}`),
      })),
      default: true,
      render: (seller) => (
        <StatusBadge
          status={seller.status}
          label={i18n.t(`admin.sellers.status.${seller.status}`)}
        />
      ),
    },
    {
      key: 'contact_email',
      label: i18n.t('admin.fields.contact_email.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (seller) => seller.contact_email ?? <span className="text-muted-foreground">—</span>,
    },
    {
      key: 'products_count',
      label: i18n.t('admin.sellers.products_column'),
      default: true,
      render: (seller) => seller.products_count,
    },
    {
      key: 'users_count',
      label: i18n.t('admin.sellers.team_column'),
      render: (seller) => seller.users_count,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (seller) => <RelativeTime iso={seller.created_at} />,
    },
  ],
})
