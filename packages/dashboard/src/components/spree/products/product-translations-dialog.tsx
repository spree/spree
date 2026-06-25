import type { TranslatableField } from '@spree/admin-sdk'
import { useTranslation } from 'react-i18next'
import { ResourceTranslationsDialog } from '@/components/spree/translations/resource-translations-dialog'
import { useProductTranslations } from '@/hooks/use-translations'

interface ProductTranslationsDialogProps {
  productId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * Product translations editor — a thin adapter over the generic
 * <ResourceTranslationsDialog>: supplies the product's translation matrix and a
 * product-scoped field-label resolver. The dialog handles the grid, locale
 * switching, and the batched save.
 */
export function ProductTranslationsDialog({
  productId,
  open,
  onOpenChange,
}: ProductTranslationsDialogProps) {
  const { t } = useTranslation()
  const { data, isLoading, isError, refetch } = useProductTranslations(productId)

  const fieldLabel = (_resourceType: string, field: TranslatableField) =>
    t([`admin.fields.product.${field.key}.label`, `admin.fields.${field.key}.label`], {
      defaultValue: field.key,
    })

  return (
    <ResourceTranslationsDialog
      open={open}
      onOpenChange={onOpenChange}
      data={data}
      isLoading={isLoading}
      isError={isError}
      fieldLabel={fieldLabel}
      onSaved={() => refetch()}
    />
  )
}
