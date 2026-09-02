import { useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  listCollectionProductsPage,
  useCollectionProducts,
  useRepositionCollectionProduct,
} from '../../../hooks/use-collections'
import { DeferredProductMembershipCard } from '../deferred-product-membership-card'

/**
 * Product membership for a collection. A manual collection is curated here —
 * adds and removes stage into the collection form and persist on its Save,
 * while reordering writes through on drop, since a collection's position
 * drives storefront display order.
 *
 * An automatic collection materializes its members from its rules, so the list
 * renders read-only: the API rejects curation there, and anything added by
 * hand would be dropped on the next regeneration.
 */
export function CollectionProductsCard({
  collectionId,
  automatic,
}: {
  collectionId: string
  automatic: boolean
}) {
  const { t } = useTranslation()
  const { storeId } = useParams({
    from: '/_authenticated/$storeId/products/collections/$collectionId',
  })
  const reposition = useRepositionCollectionProduct(collectionId)

  return (
    <DeferredProductMembershipCard
      parentId={collectionId}
      storeId={storeId}
      readOnly={automatic}
      useProducts={useCollectionProducts}
      listMembersPage={listCollectionProductsPage}
      onReorder={(productId, new_position) => reposition.mutateAsync({ productId, new_position })}
      translationNamespace="admin.collections"
      description={automatic ? t('admin.collections.products.automatic_hint') : undefined}
    />
  )
}
