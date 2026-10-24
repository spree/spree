import { i18n, type ProductFormValues } from '@spree/dashboard-core'
import { type Control, useWatch } from 'react-hook-form'

interface LabelledVariant {
  id: string
  options_text?: string | null
  sku?: string | null
}

/** The name a variant goes by in a picker. */
export function variantLabel(variant: LabelledVariant): string {
  const named = variant as LabelledVariant & { name?: string }
  return (
    named.options_text ||
    named.name ||
    named.sku ||
    variant.id ||
    i18n.t('admin.products.variants.variant_label')
  )
}

/**
 * The saved variants a file can be linked to. A card that links files saves
 * at once, so it must not offer a variant the merchant removed in the form but
 * has not saved yet: saving would delete that variant and its files with it.
 * Variants added but not saved have no id to link to.
 */
export function useAssignableVariants<V extends { id: string }>(
  control: Control<ProductFormValues>,
  variants: V[] | undefined,
): V[] {
  const liveVariants = useWatch({ control, name: 'variants' })
  const liveVariantIds = new Set((liveVariants ?? []).map((variant) => variant.id).filter(Boolean))
  return (variants ?? []).filter((variant) => liveVariantIds.has(variant.id))
}
