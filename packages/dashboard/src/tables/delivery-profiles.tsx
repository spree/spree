import type { DeliveryProfile } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { Badge, ResourceNameCell } from '@spree/dashboard-ui'
import { TruckIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

defineTable<DeliveryProfile>('delivery-profiles', {
  title: i18n.t('admin.settings_nav.items.delivery_profiles'),
  description: i18n.t('admin.table_descriptions.delivery_profiles'),
  docsPath: 'settings/shipping-methods',
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.delivery_profiles.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <TruckIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.delivery_profiles.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (profile) => (
        <div className="flex items-center gap-2">
          <ResourceNameCell
            id={profile.id}
            dataAttr="data-delivery-profile-id"
            name={profile.name}
          />
          {profile.default && (
            <Badge variant="secondary">{i18n.t('admin.delivery_profiles.default_badge')}</Badge>
          )}
        </div>
      ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.fields.delivery_profile.capabilities.label'),
      default: true,
      // What the profile can actually do reads better than its kind: a
      // physical profile may ship, offer pickup, or both.
      render: (profile) =>
        profile.digital ? (
          <Badge variant="outline">{i18n.t('admin.delivery_profiles.capabilities.digital')}</Badge>
        ) : (
          <div className="flex items-center gap-1">
            {profile.offers_shipping && (
              <Badge variant="outline">
                {i18n.t('admin.delivery_profiles.capabilities.ships')}
              </Badge>
            )}
            {profile.offers_pickup && (
              <Badge variant="outline">
                {i18n.t('admin.delivery_profiles.capabilities.pickup')}
              </Badge>
            )}
          </div>
        ),
    },
    {
      key: 'stock_location_ids',
      label: i18n.t('admin.fields.delivery_profile.origins.label'),
      default: true,
      render: (profile) =>
        profile.stock_location_ids.length === 0
          ? i18n.t('admin.delivery_profiles.all_locations')
          : i18n.t('admin.delivery_profiles.locations_count', {
              count: profile.stock_location_ids.length,
            }),
    },
    {
      key: 'products_count',
      label: i18n.t('admin.fields.delivery_profile.products_count.label'),
      default: true,
      render: (profile) => profile.products_count,
    },
    {
      key: 'delivery_zones_count',
      label: i18n.t('admin.fields.delivery_profile.zones_count.label'),
      default: true,
      render: (profile) => profile.delivery_zones_count,
    },
    {
      key: 'delivery_methods_count',
      label: i18n.t('admin.fields.delivery_profile.methods_count.label'),
      default: true,
      render: (profile) => profile.delivery_methods_count,
    },
  ],
})
