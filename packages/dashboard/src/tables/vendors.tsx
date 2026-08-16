import type { Vendor } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, StatusBadge } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { StoreIcon } from 'lucide-react'
import { VENDOR_STATUSES } from '../schemas/vendor'

defineTable<Vendor>('vendors', {
  title: i18n.t('admin.nav.vendors'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.vendors.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <StoreIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.vendors.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (vendor) => (
        <Link
          to={'/$storeId/vendors/$vendorId' as string}
          params={{ vendorId: vendor.id }}
          className="font-medium text-foreground no-underline"
        >
          {vendor.name}
        </Link>
      ),
    },
    {
      key: 'status',
      label: i18n.t('admin.fields.status.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: VENDOR_STATUSES.map((status) => ({
        value: status,
        label: i18n.t(`admin.vendors.status.${status}`),
      })),
      default: true,
      render: (vendor) => (
        <StatusBadge
          status={vendor.status}
          label={i18n.t(`admin.vendors.status.${vendor.status}`)}
        />
      ),
    },
    {
      key: 'contact_email',
      label: i18n.t('admin.fields.contact_email.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (vendor) => vendor.contact_email ?? <span className="text-muted-foreground">—</span>,
    },
    {
      key: 'products_count',
      label: i18n.t('admin.vendors.products_column'),
      default: true,
      render: (vendor) => vendor.products_count,
    },
    {
      key: 'users_count',
      label: i18n.t('admin.vendors.team_column'),
      render: (vendor) => vendor.users_count,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (vendor) => <RelativeTime iso={vendor.created_at} />,
    },
  ],
})
