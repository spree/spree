import type { CommissionRate } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { ActiveBadge, ResourceNameCell } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { HandCoinsIcon } from 'lucide-react'

defineTable<CommissionRate>('commission-rates', {
  title: i18n.t('admin.settings_nav.items.commission_rates'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.commission_rates.search_placeholder'),
  // Highest priority first — the order the marketplace actually resolves in,
  // so the list reads as the ladder it is.
  defaultSort: { field: 'priority', direction: 'desc' },
  emptyIcon: <HandCoinsIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.commission_rates.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      filterable: true,
      default: true,
      render: (rate) => (
        <ResourceNameCell
          id={rate.id}
          dataAttr="data-commission-rate-id"
          name={rate.name}
          secondary={rate.code}
        />
      ),
    },
    {
      key: 'value',
      label: i18n.t('admin.fields.commission_rate.value.label'),
      sortable: true,
      default: true,
      render: (rate) =>
        rate.kind === 'percentage'
          ? `${rate.value}%`
          : `${rate.value} ${rate.currency ?? ''}`.trim(),
    },
    {
      key: 'priority',
      label: i18n.t('admin.fields.commission_rate.priority.label'),
      sortable: true,
      default: true,
      render: (rate) => rate.priority,
    },
    {
      key: 'rules',
      label: i18n.t('admin.fields.commission_rate.rules.label'),
      default: true,
      render: (rate) =>
        rate.rules?.length
          ? rate.rules
              .map((rule) => rule.subject_name)
              .filter(Boolean)
              .join(', ')
          : i18n.t('admin.commission_rates.applies_to_everything'),
    },
    {
      key: 'enabled',
      label: i18n.t('admin.fields.enabled.label'),
      default: true,
      render: (rate) => (
        <ActiveBadge
          active={rate.enabled}
          activeLabel={i18n.t('admin.fields.enabled.label')}
          dashWhenInactive
        />
      ),
    },
  ],
})
