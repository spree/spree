import { useTaxCategories } from '../../hooks/use-tax-categories'

/**
 * Names the category a tax rate is bound to. The rate serializer carries only
 * the id, so the name is resolved from the categories list — cached and shared
 * across every row, so this costs one request per page rather than one per rate.
 */
export function TaxCategoryLabel({ id }: { id?: string | null }) {
  const { data } = useTaxCategories({ limit: 100 })

  if (!id) return <>—</>

  const category = data?.data?.find((taxCategory) => taxCategory.id === id)
  return <>{category?.name ?? id}</>
}
