import type { ReactNode } from 'react'
import { useMemo } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useProductType } from '../../../hooks/use-product-types'
import {
  type CustomFieldsFormShape,
  FormBackedCustomFieldsProvider,
} from '../custom-fields/custom-fields-inline'

interface ProductCustomFieldsProviderProps<T extends CustomFieldsFormShape> {
  form: UseFormReturn<T>
  /** Prefixed id of the product's type, when it has one. */
  productTypeId?: string | null
  children: ReactNode
}

/**
 * Custom fields for a product, scoped to its product type.
 *
 * The type decides which definitions the form shows and in which order — read
 * live, so editing a type updates every product form of that type. Products
 * without a type show every product definition, as before. Both the create and
 * edit routes go through here so they cannot drift apart.
 */
export function ProductCustomFieldsProvider<T extends CustomFieldsFormShape>({
  form,
  productTypeId,
  children,
}: ProductCustomFieldsProviderProps<T>) {
  const { data: productType } = useProductType(productTypeId ?? undefined)

  // Stable identity: the provider memoizes its definition list against this,
  // and a fresh array each render would defeat that memo on every keystroke.
  //
  // `undefined` means "no schema, show every definition", which is right for a
  // typeless product but wrong while a type is still loading — that would flash
  // the full list before narrowing. An empty array holds the space instead.
  const definitionIds = useMemo(() => {
    if (!productTypeId) return undefined
    if (!productType) return []

    return productType.custom_field_definitions?.map((definition) => definition.id) ?? []
  }, [productTypeId, productType])

  // Marks the fields the type calls required. Nothing rejects a blank one —
  // the marker is the whole enforcement.
  const requiredDefinitionIds = useMemo(
    () =>
      productType?.custom_field_definitions
        ?.filter((definition) => definition.required)
        .map((definition) => definition.id),
    [productType?.custom_field_definitions],
  )

  return (
    <FormBackedCustomFieldsProvider
      form={form}
      resourceType="Spree::Product"
      definitionIds={definitionIds}
      requiredDefinitionIds={requiredDefinitionIds}
    >
      {children}
    </FormBackedCustomFieldsProvider>
  )
}
