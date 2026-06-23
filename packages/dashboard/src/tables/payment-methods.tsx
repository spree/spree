import type { PaymentMethod } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { CreditCardIcon } from 'lucide-react'

defineTable<PaymentMethod>('payment-methods', {
  title: i18n.t('admin.payment_methods.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.payment_methods.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <CreditCardIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.payment_methods.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (pm) => (
        <ResourceNameCell
          id={pm.id}
          dataAttr="data-payment-method-id"
          name={pm.name}
          secondary={pm.description}
        />
      ),
    },
    {
      key: 'type',
      label: i18n.t('admin.fields.payment_method.type.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (pm) => <Badge variant="outline">{pm.type}</Badge>,
    },
    {
      key: 'storefront_visible',
      label: i18n.t('admin.payment_methods.columns.storefront'),
      filterable: true,
      filterType: 'boolean',
      default: true,
      render: (pm) => (
        <ActiveBadge
          active={pm.storefront_visible}
          activeLabel={i18n.t('admin.payment_methods.storefront.visible')}
          inactiveLabel={i18n.t('admin.payment_methods.storefront.admin_only')}
        />
      ),
    },
    {
      key: 'active',
      label: i18n.t('admin.fields.status.label'),
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (pm) => (
        <ActiveBadge
          active={pm.active}
          activeLabel={i18n.t('admin.fields.active.label')}
          inactiveLabel={i18n.t('admin.payment_methods.status.disabled')}
        />
      ),
    },
  ],
})
