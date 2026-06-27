import type { TranslatableField } from '@spree/admin-sdk'
import { useTranslation } from 'react-i18next'
import { ResourceTranslationsDialog } from '@/components/spree/translations/resource-translations-dialog'
import { useCategoryTranslations } from '@/hooks/use-translations'

interface CategoryTranslationsDialogProps {
  categoryId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * Category translations editor — a thin adapter over the generic
 * <ResourceTranslationsDialog>. Fetches the category's translation matrix and
 * saves all locales in one batch.
 */
export function CategoryTranslationsDialog({
  categoryId,
  open,
  onOpenChange,
}: CategoryTranslationsDialogProps) {
  const { t } = useTranslation()
  const { data, isLoading, isError, refetch } = useCategoryTranslations(categoryId)

  const fieldLabel = (resourceType: string, field: TranslatableField) =>
    t([`admin.fields.${resourceType}.${field.key}.label`, `admin.fields.${field.key}.label`], {
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
