import type { Supplier } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ResourceNameCell } from '@spree/dashboard-ui'
import { Building2Icon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

defineTable<Supplier>('suppliers', {
  title: i18n.t('admin.suppliers.title'),
  description: i18n.t('admin.table_descriptions.suppliers'),
  searchParam: 'name_or_contact_name_or_email_cont',
  searchPlaceholder: i18n.t('admin.suppliers.table.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <Building2Icon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.suppliers.table.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (supplier) => (
        <ResourceNameCell id={supplier.id} dataAttr="data-supplier-id" name={supplier.name} />
      ),
    },
    {
      key: 'contact_name',
      label: i18n.t('admin.suppliers.columns.contact'),
      sortable: true,
      default: true,
      render: (supplier) => supplier.contact_name ?? '—',
    },
    {
      key: 'email',
      label: i18n.t('admin.fields.email.label'),
      sortable: true,
      default: true,
      render: (supplier) => supplier.email ?? '—',
    },
    {
      key: 'phone',
      label: i18n.t('admin.fields.phone.label'),
      default: true,
      render: (supplier) => supplier.phone ?? '—',
    },
    {
      key: 'purchase_orders_count',
      label: i18n.t('admin.suppliers.columns.orders'),
      default: true,
      className: 'tabular-nums',
      render: (supplier) => supplier.purchase_orders_count,
    },
  ],
})
