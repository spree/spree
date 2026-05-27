import type { CustomFieldDefinition } from '@spree/admin-sdk'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import { TagIcon } from 'lucide-react'
import { i18n } from '@/lib/i18n'
import { defineTable } from '@/lib/table-registry'
import {
  DEFAULT_RESOURCE_TYPES,
  FIELD_TYPES,
  fieldTypeLabel,
  resourceTypeLabel,
} from '@/schemas/custom-field-definition'

const t = (key: string) => i18n.t(key)

defineTable<CustomFieldDefinition>('custom-field-definitions', {
  title: t('admin.custom_field_definitions.table_title'),
  searchParam: 'search',
  searchPlaceholder: t('admin.custom_field_definitions.search_placeholder'),
  defaultSort: { field: 'resource_type', direction: 'asc' },
  emptyIcon: <TagIcon className="size-8 text-muted-foreground" />,
  emptyMessage: t('admin.custom_field_definitions.empty'),
  columns: [
    {
      key: 'name',
      label: t('admin.fields.custom_field_definition.label.label'),
      sortable: true,
      filterable: true,
      default: true,
      ransackAttribute: 'name',
      render: (def) => (
        <ResourceNameCell
          id={def.id}
          dataAttr="data-custom-field-definition-id"
          name={def.label}
          secondary={
            <code className="font-mono">
              {def.namespace}.{def.key}
            </code>
          }
        />
      ),
    },
    {
      key: 'resource_type',
      label: t('admin.fields.custom_field_definition.resource_type.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: DEFAULT_RESOURCE_TYPES.map((value) => ({
        value,
        label: resourceTypeLabel(value),
      })),
      default: true,
      render: (def) => <Badge variant="secondary">{resourceTypeLabel(def.resource_type)}</Badge>,
    },
    {
      key: 'field_type',
      label: t('admin.fields.custom_field_definition.field_type.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: FIELD_TYPES.map((value) => ({ value, label: fieldTypeLabel(value) })),
      default: true,
      render: (def) => <Badge variant="outline">{fieldTypeLabel(def.field_type)}</Badge>,
    },
    {
      key: 'storefront_visible',
      label: t('admin.fields.custom_field_definition.storefront_visible.column_label'),
      default: true,
      render: (def) => (
        <ActiveBadge
          active={def.storefront_visible}
          activeLabel={t('admin.custom_field_definitions.storefront_visible.visible')}
          inactiveLabel={t('admin.custom_field_definitions.storefront_visible.admin_only')}
        />
      ),
    },
  ],
})
