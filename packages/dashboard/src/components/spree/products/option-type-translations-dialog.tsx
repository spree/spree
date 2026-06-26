import type { TranslatableField } from '@spree/admin-sdk'
import { useTranslation } from 'react-i18next'
import { ResourceTranslationsDialog } from '@/components/spree/translations/resource-translations-dialog'
import { useOptionTypeTranslations } from '@/hooks/use-translations'

interface OptionTypeTranslationsDialogProps {
  optionTypeId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * Option type translations editor — a thin adapter over the generic
 * <ResourceTranslationsDialog>. Fetches the option type's translation matrix
 * with its option values nested under `children`, so the dialog renders the
 * type and all its values as rows and saves them in one batch.
 */
export function OptionTypeTranslationsDialog({
  optionTypeId,
  open,
  onOpenChange,
}: OptionTypeTranslationsDialogProps) {
  const { t } = useTranslation()
  const { data, isLoading, isError, refetch } = useOptionTypeTranslations(optionTypeId)

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
