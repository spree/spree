import { useStore } from '@spree/dashboard-core'
import {
  listCategoryProductsPage,
  useCategoryProducts,
  useRepositionCategoryProduct,
} from '../../../hooks/use-categories'
import { DeferredProductMembershipCard } from '../deferred-product-membership-card'

/**
 * Manual product membership + ordering for a category. Adds and removes stage
 * into the category form and persist on its Save; reordering writes through on
 * drop, since a category's position drives storefront display order.
 *
 * On a new category (`categoryId` unset) the picks stage into the form and
 * are added once the category is created; reordering waits until then.
 */
export function CategoryProductsCard({ categoryId }: { categoryId?: string }) {
  const { storeId } = useStore()
  const reposition = useRepositionCategoryProduct(categoryId ?? '')

  return (
    <DeferredProductMembershipCard
      parentId={categoryId}
      storeId={storeId}
      useProducts={useCategoryProducts}
      listMembersPage={listCategoryProductsPage}
      onReorder={
        categoryId
          ? (productId, new_position) => reposition.mutateAsync({ productId, new_position })
          : undefined
      }
      translationNamespace="admin.categories"
    />
  )
}
