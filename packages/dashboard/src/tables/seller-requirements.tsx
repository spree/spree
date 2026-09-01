import type { SellerRequirement } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, Badge, ResourceNameCell } from '@spree/dashboard-ui'
import { ClipboardCheckIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'

defineTable<SellerRequirement>('seller-requirements', {
  title: i18n.t('admin.seller_requirements.title'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.seller_requirements.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <ClipboardCheckIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.seller_requirements.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      default: true,
      render: (requirement) => (
        <ResourceNameCell
          id={requirement.id}
          dataAttr="data-seller-requirement-id"
          name={requirement.name}
          secondary={requirement.description ?? undefined}
        />
      ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.seller_requirements.columns.kind'),
      default: true,
      render: (requirement) => (
        <Badge variant="outline">
          {i18n.t(`admin.seller_requirements.kinds.${requirement.kind}`, {
            defaultValue: requirement.kind,
          })}
        </Badge>
      ),
    },
    {
      key: 'required',
      label: i18n.t('admin.seller_requirements.columns.required'),
      default: true,
      render: (requirement) => (
        <ActiveBadge
          active={requirement.required}
          activeLabel={i18n.t('admin.seller_requirements.required.yes')}
          inactiveLabel={i18n.t('admin.seller_requirements.required.no')}
        />
      ),
    },
    {
      key: 'active',
      label: i18n.t('admin.fields.status.label'),
      default: true,
      render: (requirement) => (
        <ActiveBadge
          active={requirement.active}
          activeLabel={i18n.t('admin.fields.active.label')}
          inactiveLabel={i18n.t('admin.seller_requirements.status.disabled')}
        />
      ),
    },
  ],
})
