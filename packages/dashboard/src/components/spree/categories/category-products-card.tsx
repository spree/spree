import { useParams } from '@tanstack/react-router'
import { useCategoryProducts, useRepositionCategoryProduct } from '../../../hooks/use-categories'
import { DeferredProductMembershipCard } from '../deferred-product-membership-card'

/**
 * Manual product membership + ordering for a category. Adds and removes stage
 * into the category form and persist on its Save; reordering writes through on
 * drop, since a category's position drives storefront display order.
 *
 * Only rendered for a persisted category (needs an id to list or mutate).
 */
export function CategoryProductsCard({ categoryId }: { categoryId: string }) {
  const { storeId } = useParams({
    from: '/_authenticated/$storeId/products/categories/$categoryId',
  })
  const reposition = useRepositionCategoryProduct(categoryId)

  return (
    <DeferredProductMembershipCard
      parentId={categoryId}
      storeId={storeId}
      useProducts={useCategoryProducts}
      onReorder={(productId, new_position) => reposition.mutateAsync({ productId, new_position })}
      translationNamespace="admin.categories"
    />
  )
}
