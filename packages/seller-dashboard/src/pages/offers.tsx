import type { BulkAction, BulkActionOutcome, ResourceSearch } from '@spree/dashboard-core'
import { PageHeader, ResourcePickerSheet, ResourceTable, Subject } from '@spree/dashboard-core'
import { Button, useRowClickBridge } from '@spree/dashboard-ui'
import { PlusIcon, SendIcon } from '@spree/dashboard-ui/icons'
import type { Product, Variant } from '@spree/seller-sdk'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/offers'

/**
 * This seller's offers on the marketplace's own products.
 *
 * A rail entry of its own rather than a tab on Products: the two are
 * different resources with different moves — a product this seller owns
 * outright is theirs to name and describe, while an offer is a price and a
 * condition against somebody else's listing
 * (docs/plans/6.0-seller-master-catalog-listings.md, Decision 11).
 */
export function OffersPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const navigate = useNavigate()
  const [pickerOpen, setPickerOpen] = useState(false)

  const open = (variantId: string) =>
    navigate({ to: '/$sellerId/offers/$variantId', params: { sellerId, variantId } })

  useRowClickBridge('data-offer-id', open)

  const bulkActions = useMemo<BulkAction<unknown>[]>(() => {
    // There is no bulk endpoint for offers: each submission is its own
    // review, so this loops the member action and counts what moved. Only
    // submit is offered — taking an offer down is a decision a seller makes
    // one listing at a time, on the offer's own page.
    const submitAction: BulkAction<unknown> = {
      key: 'submit-for-review',
      label: t('offers.submit_for_review'),
      icon: <SendIcon className="size-4" />,
      subject: Subject.Variant,
      confirm: {
        title: t('offers.bulk.submit_confirm_title'),
        message: t('offers.bulk.submit_confirm_description'),
        confirmLabel: t('offers.submit_for_review'),
      },
      run: async ({ ids }): Promise<BulkActionOutcome> => {
        const results = await Promise.allSettled(
          ids.map((id) => sellerClient().variants.submit(id)),
        )

        return { count: results.filter((result) => result.status === 'fulfilled').length }
      },
      successMessage: t('offers.bulk.submitted'),
      errorMessage: t('offers.bulk.submit_failed'),
    }

    return [submitAction]
  }, [t])

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={t('offers.title')} />

      <ResourceTable<Variant>
        tableKey="seller-offers"
        queryKey="seller-offers"
        // `product` names what each offer sits on; without it the list can
        // only show a SKU, which is not how a seller thinks about a catalog
        // whose products belong to somebody else.
        queryFn={(params) => sellerClient().variants.list({ ...params, expand: ['product'] })}
        searchParams={search}
        bulkActions={bulkActions}
        actions={() => (
          <Button onClick={() => setPickerOpen(true)}>
            <PlusIcon className="size-4" />
            {t('offers.add')}
          </Button>
        )}
      />

      {/* Listing an offer starts by finding the product, so the picker is the
          entry point rather than a blank form. */}
      <ResourcePickerSheet<Product>
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        selectedIds={[]}
        queryKey={`seller-${sellerId}-master-products`}
        title={t('offers.picker.title')}
        description={t('offers.picker.description')}
        searchPlaceholder={t('offers.picker.search_placeholder')}
        confirmLabel={t('offers.picker.confirm')}
        search={async (query, page) => {
          const response = await sellerClient().masterProducts.list({
            page,
            ...(query ? { name_cont: query } : {}),
          })
          return { data: response.data, meta: response.meta }
        }}
        getOptionLabel={(product) => product.name}
        getOptionImageUrl={(product) => product.thumbnail_url}
        onConfirm={(ids) => {
          const productId = ids[0]
          if (!productId) return

          setPickerOpen(false)
          navigate({
            to: '/$sellerId/offers/new',
            params: { sellerId },
            search: { product: productId },
          })
        }}
      />
    </div>
  )
}
