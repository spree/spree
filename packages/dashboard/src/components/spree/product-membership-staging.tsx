import type { Product } from '@spree/admin-sdk'
import type { QueryClient, QueryKey } from '@tanstack/react-query'
import { createContext, type ReactNode, useCallback, useContext, useMemo } from 'react'
import { type FieldValues, type Path, type UseFormReturn, useController } from 'react-hook-form'

/**
 * The staged membership edits a deferred products card reads and writes.
 * Held in the surrounding form rather than in the card, so the page's Save
 * and Discard govern them like any other field.
 */
export interface ProductMembershipStaging {
  adds: Product[]
  removes: string[]
  setAdds: (products: Product[]) => void
  setRemoves: (ids: string[]) => void
  /** True when anything is staged — drives the "applies on save" hint. */
  dirty: boolean
  /** Clears both sets. Called after a successful flush. */
  reset: () => void
}

const StagingContext = createContext<ProductMembershipStaging | null>(null)

/** The staged value as it lives in form state. */
export interface ProductMembershipStagingValue {
  adds: Product[]
  removes: string[]
}

export const EMPTY_STAGING: ProductMembershipStagingValue = { adds: [], removes: [] }

/**
 * Backs the staged membership with a real form field, so react-hook-form
 * owns it: `isDirty` flips when a product is staged (enabling Save and the
 * unsaved-changes guards), and Discard rolls it back with everything else.
 *
 * The field holds `Product` records rather than ids alone, because a staged
 * addition has to render a name and thumbnail before it exists server-side.
 * Keep the field out of the schema's parsed output — `useController` reads
 * and writes it directly, and the submit handler consumes it before the Zod
 * parse strips it.
 */
export function ProductMembershipStagingProvider<TFieldValues extends FieldValues>({
  form,
  name,
  children,
}: {
  form: UseFormReturn<TFieldValues, any, any>
  /** Form field holding the staged sets, e.g. `staged_products`. */
  name: Path<TFieldValues>
  children: ReactNode
}) {
  const { field } = useController({ control: form.control, name })
  const value = (field.value as ProductMembershipStagingValue | undefined) ?? EMPTY_STAGING

  const setAdds = useCallback(
    (adds: Product[]) => field.onChange({ ...value, adds }),
    [field, value],
  )
  const setRemoves = useCallback(
    (removes: string[]) => field.onChange({ ...value, removes }),
    [field, value],
  )
  const reset = useCallback(() => field.onChange(EMPTY_STAGING), [field])

  const staging = useMemo<ProductMembershipStaging>(
    () => ({
      adds: value.adds,
      removes: value.removes,
      setAdds,
      setRemoves,
      dirty: value.adds.length > 0 || value.removes.length > 0,
      reset,
    }),
    [value, setAdds, setRemoves, reset],
  )

  return <StagingContext.Provider value={staging}>{children}</StagingContext.Provider>
}

/**
 * The staged membership for the surrounding form. Throws outside a provider
 * rather than silently staging into nothing, which would look like a card
 * that accepts edits and drops them on Save.
 */
export function useProductMembershipStaging(): ProductMembershipStaging {
  const staging = useContext(StagingContext)
  if (!staging) {
    throw new Error(
      'useProductMembershipStaging must be used inside <ProductMembershipStagingProvider>',
    )
  }
  return staging
}

/**
 * Applies staged membership through a parent's nested products endpoints,
 * then refreshes the list once.
 *
 * Removals go first, so a product removed and re-added in one session ends
 * with fresh membership rather than a delete landing on top of the re-add.
 *
 * The single refresh at the end is the point: the individual writes don't
 * invalidate, and the parent's own update holds the products list back, so
 * the list keeps its pre-save rows — staged ones still pinned on top — until
 * everything is written. Without that it refetches mid-save and paints the
 * old membership for a frame before the real state lands.
 *
 * Awaited, so the fresh rows are in the cache before the caller resets the
 * form. The two have to land in one commit: reset first and the staged rows
 * vanish a frame before the server's arrive (the list drops to its pre-save
 * contents); refresh first without awaiting and both are drawn at once, so
 * every added product appears twice.
 */
export async function flushProductMembership({
  staging,
  add,
  remove,
  queryClient,
  productsKey,
}: {
  staging: ProductMembershipStagingValue
  add: (productIds: string[]) => Promise<unknown>
  remove: (productIds: string[]) => Promise<unknown>
  queryClient: QueryClient
  /** Store-scoped key prefix of the nested products query. */
  productsKey: QueryKey
}): Promise<void> {
  if (staging.removes.length > 0) await remove(staging.removes)
  if (staging.adds.length > 0) await add(staging.adds.map((product) => product.id))

  await queryClient.invalidateQueries({ queryKey: productsKey })
}
