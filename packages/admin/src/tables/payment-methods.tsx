import type { PaymentMethod } from '@spree/admin-sdk'
import { CreditCardIcon } from 'lucide-react'
import { ResourceNameCell } from '@/components/spree/resource-name-cell'
import { ActiveBadge, Badge } from '@/components/ui/badge'
import { defineTable } from '@/lib/table-registry'

defineTable<PaymentMethod>('payment-methods', {
  title: 'Payment Methods',
  searchParam: 'name_cont',
  searchPlaceholder: 'Search by name…',
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <CreditCardIcon className="size-8 text-muted-foreground" />,
  emptyMessage: 'No payment methods configured',
  columns: [
    {
      key: 'name',
      label: 'Name',
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
      label: 'Provider',
      sortable: true,
      filterable: true,
      default: true,
      render: (pm) => <Badge variant="outline">{pm.type}</Badge>,
    },
    {
      key: 'storefront_visible',
      label: 'Storefront',
      filterable: true,
      filterType: 'boolean',
      default: true,
      render: (pm) => (
        <ActiveBadge
          active={pm.storefront_visible}
          activeLabel="Visible"
          inactiveLabel="Admin only"
        />
      ),
    },
    {
      key: 'active',
      label: 'Status',
      filterable: true,
      default: true,
      filterType: 'boolean',
      render: (pm) => (
        <ActiveBadge active={pm.active} activeLabel="Active" inactiveLabel="Disabled" />
      ),
    },
  ],
})
