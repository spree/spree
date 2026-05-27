import { Button } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { adminClient } from '@/client'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import '@/tables/orders'

export const Route = createFileRoute('/_authenticated/$storeId/orders/drafts')({
  validateSearch: resourceSearchSchema,
  component: DraftOrdersPage,
})

function DraftOrdersPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="orders"
      queryKey="draft-orders"
      queryFn={(params) => adminClient.orders.list(params)}
      searchParams={searchParams}
      defaultParams={{ incomplete: 1 }}
      title={t('admin.pages.orders.drafts_title')}
      actions={
        <Button size="sm" className="h-[2.125rem]">
          <PlusIcon className="size-4" />
          {t('admin.pages.orders.new.title')}
        </Button>
      }
    />
  )
}
