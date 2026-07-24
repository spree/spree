/**
 * Brands index page, rendered by the `brands.index` file route. Uses the
 * dashboard's `<ResourceTable>` for filtering, sorting, pagination, and
 * bulk-action chrome — the same UX as core's Products/Customers/Orders pages.
 * Like those pages, the table is the whole page: the toolbar carries the
 * title (from the table definition) and the primary action.
 *
 * The table's columns and filters are declared via `defineTable('brands', ...)`
 * in `../index.tsx` (alongside the plugin entry); ResourceTable reads from
 * that registry by tableKey.
 */
import { type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { brandsClient } from '../client'
import type { Brand } from '../types'

interface BrandsListPageProps {
  searchParams: ResourceSearch
}

export function BrandsListPage({ searchParams }: BrandsListPageProps) {
  const { t } = useTranslation()

  return (
    <ResourceTable<Brand>
      tableKey="brands"
      queryKey="brands"
      // ResourceTable hands `params` to queryFn as `Record<string, unknown>`
      // (its internal builder doesn't know what each table's API accepts).
      // We narrow to our client's known param shape at the boundary.
      queryFn={(params) => brandsClient.list(params as Record<string, never>)}
      searchParams={searchParams}
      actions={
        <Button size="sm" className="h-[2.125rem]">
          <PlusIcon className="size-4" />
          {t('admin.brands_plugin.page.new_cta')}
        </Button>
      }
    />
  )
}
