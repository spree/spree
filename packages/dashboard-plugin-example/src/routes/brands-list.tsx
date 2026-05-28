/**
 * Brands index page. Mounted at `/$storeId/brands` via the plugin's route
 * registration in `index.tsx`. Uses the dashboard's `<ResourceTable>` for
 * filtering, sorting, pagination, and bulk-action chrome — the same UX as
 * core's Products/Customers/Orders pages.
 *
 * The table's columns and filters are declared via `defineTable('brands', ...)`
 * in `../index.tsx` (alongside the plugin entry); ResourceTable reads from
 * that registry by tableKey.
 *
 * Plugin route components receive `{ params, storeId, searchParams }` from
 * the catch-all dispatcher. We forward `searchParams` straight to
 * ResourceTable so filter/sort/pagination round-trip through the URL.
 */
import { PageHeader, type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { Button, ResourceLayout } from '@spree/dashboard-ui'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { brandsClient } from '../client'
import type { Brand } from '../types'

interface BrandsListPageProps {
  searchParams: Record<string, unknown>
}

export function BrandsListPage({ searchParams }: BrandsListPageProps) {
  const { t } = useTranslation()

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={t('admin.brands_plugin.page.title')}
          subtitle={t('admin.brands_plugin.page.subtitle')}
          actions={
            <Button size="sm">
              <PlusIcon className="size-4" />
              {t('admin.brands_plugin.page.new_cta')}
            </Button>
          }
        />
      }
      main={
        <ResourceTable<Brand>
          tableKey="brands"
          queryKey="brands"
          // ResourceTable hands `params` to queryFn as `Record<string, unknown>`
          // (its internal builder doesn't know what each table's API accepts).
          // We narrow to our client's known param shape at the boundary.
          queryFn={(params) => brandsClient.list(params as Record<string, never>)}
          // The catch-all dispatcher passes searchParams as a generic record
          // because it can't know each plugin's parsed shape. ResourceTable
          // expects a Zod-validated `ResourceSearch`; defaults fill in any
          // missing fields, so the cast is safe at the boundary.
          searchParams={searchParams as ResourceSearch}
        />
      }
    />
  )
}
