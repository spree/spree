import type { Company } from '@spree/admin-sdk'
import { defineTable } from '@spree/dashboard-core'
import { RelativeTime } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import { Building2Icon } from 'lucide-react'

defineTable<Company>('companies', {
  title: i18n.t('admin.nav.companies'),
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
      filterable: true,
      default: true,
      render: (company) => (
        <Link
          to={'/$storeId/companies/$companyId' as string}
          params={{ companyId: company.id }}
          className="font-medium text-foreground no-underline"
        >
          {company.name}
        </Link>
      ),
    },
    {
      key: 'locations_count',
      label: i18n.t('admin.companies.locations_column'),
      default: true,
      render: (company) => company.locations_count,
    },
    {
      // Off by default: only a merchant reconciling against an ERP or PIM
      // wants a column of foreign keys, and they can switch it on.
      key: 'external_references',
      label: i18n.t('admin.fields.external_references.label'),
      filterable: true,
      default: false,
      render: (company) => Object.values(company.external_references ?? {}).join(', ') || '—',
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
