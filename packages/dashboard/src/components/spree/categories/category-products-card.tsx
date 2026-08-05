import { useParams } from '@tanstack/react-router'
import {
  useAddCategoryProducts,
  useCategoryProducts,
  useRemoveCategoryProduct,
  useRemoveCategoryProducts,
  useRepositionCategoryProduct,
} from '../../../hooks/use-categories'
import { ProductMembershipCard } from '../product-membership-card'

const hooks = {
  useProducts: useCategoryProducts,
  useAdd: useAddCategoryProducts,
  useRemoveOne: useRemoveCategoryProduct,
  useRemoveMany: useRemoveCategoryProducts,
  useReposition: useRepositionCategoryProduct,
}

/**
 * Manual product membership + ordering for a category — the SPA equivalent of
 * the old Rails admin taxon "Products" panel. Only rendered for a persisted
 * category (needs an id to mutate).
 */
export function CategoryProductsCard({ categoryId }: { categoryId: string }) {
  const { storeId } = useParams({
    from: '/_authenticated/$storeId/products/categories/$categoryId',
  })

  return (
    <ProductMembershipCard
      parentId={categoryId}
      storeId={storeId}
      hooks={hooks}
      translationNamespace="admin.categories"
    />
  )
}
