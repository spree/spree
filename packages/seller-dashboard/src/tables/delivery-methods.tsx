import { defineTable } from '@spree/dashboard-core'
import { Badge, ResourceNameCell } from '@spree/dashboard-ui'
import { TruckIcon } from '@spree/dashboard-ui/icons'
import type { DeliveryMethod } from '@spree/seller-sdk'
import i18n from 'i18next'

defineTable<DeliveryMethod>('seller-delivery-methods', {
  title: i18n.t('delivery_methods.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('delivery_methods.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <TruckIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('delivery_methods.empty.title'),
  columns: [
    {
      key: 'name',
      label: i18n.t('delivery_methods.columns.name'),
      sortable: true,
      default: true,
      // A marketplace method the operator merely shares renders as plain
      // text: the API refuses every write against it, so making its name
      // look clickable would open an editor whose Save could only 404.
      render: (method) =>
        method.editable ? (
          <ResourceNameCell
            id={method.id}
            dataAttr="data-delivery-method-id"
            name={method.name}
            secondary={method.admin_name ?? undefined}
          />
        ) : (
          <div className="flex flex-col">
            <span className="font-medium">{method.name}</span>
            {method.admin_name && (
              <span className="text-muted-foreground text-xs">{method.admin_name}</span>
            )}
          </div>
        ),
    },
    // Whose method it is. A marketplace method the operator shares is listed
    // so a seller can see what already ships their goods, and cannot be
    // changed here.
    {
      key: 'editable',
      label: i18n.t('delivery_methods.columns.owner'),
      default: true,
      render: (method) => (
        <Badge variant={method.editable ? 'default' : 'secondary'}>
          {method.editable
            ? i18n.t('delivery_methods.owner.mine')
            : i18n.t('delivery_methods.owner.marketplace')}
        </Badge>
      ),
    },
    {
      key: 'storefront_visible',
      label: i18n.t('delivery_methods.columns.visibility'),
      default: true,
      render: (method) => (
        <Badge variant={method.storefront_visible ? 'default' : 'outline'}>
          {method.storefront_visible
            ? i18n.t('delivery_methods.visibility.storefront')
            : i18n.t('delivery_methods.visibility.hidden')}
        </Badge>
      ),
    },
  ],
})
