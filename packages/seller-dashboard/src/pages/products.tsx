import { type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { Button, useRowClickBridge } from '@spree/dashboard-ui'
import type { Product } from '@spree/seller-sdk'
import { useNavigate, useParams } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/products'

/** This seller's own catalog. */
export function ProductsPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const navigate = useNavigate()

  const open = (productId: string) =>
    navigate({ to: '/$sellerId/products/$productId', params: { sellerId, productId } })

  useRowClickBridge('data-product-id', open)

  return (
    <div className="flex flex-col gap-4">
      <h1 className="font-medium text-2xl">{t('products.title')}</h1>

      <ResourceTable<Product>
        tableKey="seller-products"
        queryKey="seller-products"
        queryFn={(params) => sellerClient().products.list(params)}
        searchParams={search}
        actions={
          <Button onClick={() => navigate({ to: '/$sellerId/products/new', params: { sellerId } })}>
            <PlusIcon className="size-4" />
            {t('products.add')}
          </Button>
        }
      />
    </div>
  )
}
