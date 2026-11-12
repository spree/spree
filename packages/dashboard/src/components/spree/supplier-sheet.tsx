import type { Supplier, SupplierCreateParams } from '@spree/admin-sdk'
import { RecordMetadataSection } from '@spree/dashboard-core'
import {
  Button,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { useCreateSupplier, useSupplier, useUpdateSupplier } from '../../hooks/use-suppliers'
import { SupplierFormFields, useSupplierForm } from './supplier-form'

/**
 * Create or correct a supplier, wherever the merchant needs one.
 *
 * The purchase order screen opens it too: buying from someone new is part of
 * raising the order, not a detour through another screen.
 */
export function SupplierSheet({
  id,
  open,
  onOpenChange,
  onCreated,
}: {
  id?: string
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Handed the new record, so a caller can select what it just created. */
  onCreated?: (supplier: Supplier) => void
}) {
  const { t } = useTranslation()
  const { data: supplier } = useSupplier(id)
  const createMutation = useCreateSupplier()
  const updateMutation = useUpdateSupplier(id ?? '')
  const mutation = id ? updateMutation : createMutation

  // The sheet edits every field, so the payload always carries the name.
  const { form, set, save, submitAttempted } = useSupplierForm(supplier, (payload) =>
    mutation.mutateAsync(payload as SupplierCreateParams),
  )

  async function handleSubmit() {
    const saved = await save()
    if (!saved) return
    if (!id) onCreated?.(saved)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>
            {id ? t('admin.suppliers.edit_title') : t('admin.suppliers.new_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.suppliers.sheet_description')}</SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <SupplierFormFields form={form} set={set} submitAttempted={submitAttempted} />
          {id && <RecordMetadataSection metadata={supplier?.metadata} />}
        </div>

        <SheetFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={mutation.isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          {/* Clickable with the name still blank: pressing Save is how the
              merchant asks what is missing, and a button that only greys out
              never says. */}
          <Button type="button" onClick={handleSubmit} disabled={mutation.isPending}>
            {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
