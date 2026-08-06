import { useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import {
  useAddCollectionProducts,
  useCollectionProducts,
  useRemoveCollectionProduct,
  useRemoveCollectionProducts,
  useRepositionCollectionProduct,
} from '../../../hooks/use-collections'
import { ProductMembershipCard } from '../product-membership-card'

const hooks = {
  useProducts: useCollectionProducts,
  useAdd: useAddCollectionProducts,
  useRemoveOne: useRemoveCollectionProduct,
  useRemoveMany: useRemoveCollectionProducts,
  useReposition: useRepositionCollectionProduct,
}

/**
 * Product membership for a collection. A manual collection is curated here; an
 * automatic one materializes its members from its rules, so the list renders
 * read-only — the API rejects curation there, and anything added by hand would
 * be dropped on the next regeneration.
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

  return (
    <ProductMembershipCard
      parentId={collectionId}
      storeId={storeId}
      hooks={hooks}
      translationNamespace="admin.collections"
      readOnly={automatic}
      description={automatic ? t('admin.collections.products.automatic_hint') : undefined}
    />
  )
}
