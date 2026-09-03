import type { Company } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime, ResourceNameCell } from '@spree/dashboard-ui'
import { Building2Icon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { CompanyKindBadge } from '../components/spree/company-kind-badge'

defineTable<Company>('companies', {
  title: i18n.t('admin.nav.companies'),
  description: i18n.t('admin.table_descriptions.companies'),
  searchParam: 'name_cont',
  searchPlaceholder: i18n.t('admin.companies.search_placeholder'),
  defaultSort: { field: 'name', direction: 'asc' },
  emptyIcon: <Building2Icon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.companies.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (company) => (
        <ResourceNameCell
          id={company.id}
          dataAttr="data-company-id"
          name={company.name}
          // The node's place in the tree — "Acme / EMEA" — so a flat,
          // paginated list still reads hierarchically.
          secondary={
            company.ancestors.length > 0
              ? company.ancestors.map((ancestor) => ancestor.name).join(' / ')
              : undefined
          }
        />
      ),
    },
    {
      key: 'kind',
      label: i18n.t('admin.fields.company.kind.label'),
      sortable: true,
      filterable: true,
      filterType: 'enum',
      filterOptions: [
        { value: 'company', label: i18n.t('admin.companies.kind.company') },
        { value: 'division', label: i18n.t('admin.companies.kind.division') },
      ],
      quickFilter: true,
      default: true,
      render: (company) => <CompanyKindBadge kind={company.kind} />,
    },
    {
      key: 'members_count',
      label: i18n.t('admin.companies.members_column'),
      default: true,
      render: (company) => company.members_count,
    },
    {
      key: 'children_count',
      label: i18n.t('admin.companies.sub_units.title'),
      default: true,
      render: (company) => company.children_count,
    },
    {
      key: 'created_at',
      label: i18n.t('admin.fields.created_at.label'),
      sortable: true,
      default: true,
      render: (company) => <RelativeTime iso={company.created_at} />,
    },
  ],
})
