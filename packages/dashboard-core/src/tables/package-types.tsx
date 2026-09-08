import { RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import type { PanelPackageType } from '../api-client'
import { defineTable } from '../lib/table-registry'

defineTable<PanelPackageType>('package-types', {
  title: i18n.t('admin.package_types.table_title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.package_types.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <PackageIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.package_types.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.package_type.name.label'),
      sortable: true,
      default: true,
      render: (packageType) => (
        <ResourceNameCell
          id={packageType.id}
          // Omitted on a row this panel may read but not write, so the row
          // click bridge never opens an edit sheet whose save could only
          // 404. A seller sees the marketplace's packaging to know what they
          // may pack into; it is not theirs to change.
          dataAttr={packageType.editable === false ? undefined : 'data-package-type-id'}
          name={packageType.name}
          // This owner's own box, called out because every parcel quote from
          // their warehouse is built on it.
          secondary={packageType.default ? i18n.t('admin.package_types.default_badge') : undefined}
        />
      ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.fields.package_type.kind.label'),
      sortable: true,
      default: true,
      render: (packageType) => i18n.t(`admin.package_types.kinds.${packageType.kind}`),
    },
    {
      key: 'dimensions',
      label: i18n.t('admin.package_types.dimensions_column'),
      default: true,
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      // Three numbers mean nothing without the unit they were measured in —
      // the same figures read as inches or centimetres differ sixteenfold by
      // volume, which is what the freight tiers compare.
      render: (packageType) =>
        packageType.length && packageType.width && packageType.height
          ? `${packageType.length} × ${packageType.width} × ${packageType.height} ${packageType.dimensions_unit}`
          : '—',
    },
    {
      key: 'volume',
      label: i18n.t('admin.package_types.volume_column'),
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (packageType) =>
        packageType.volume ? `${Number(packageType.volume).toFixed(3)} m³` : '—',
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      filterable: true,
      filterType: 'date',
      className: 'text-sm text-muted-foreground whitespace-nowrap',
      render: (packageType) => <RelativeTime iso={packageType.created_at} />,
    },
  ],
})
