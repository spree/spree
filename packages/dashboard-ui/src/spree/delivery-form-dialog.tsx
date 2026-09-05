import type { UseFormReturn } from 'react-hook-form'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import {
  Combobox,
  ComboboxButtonTrigger,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxSearch,
  ComboboxTriggerPlaceholder,
  ComboboxValue,
} from '../ui/combobox'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '../ui/dialog'
import { Field, FieldError, FieldLabel } from '../ui/field'
import { Input } from '../ui/input'

/** The form shape both panels bind for one consignment. */
export type DeliveryFormFields = {
  tracking_number: string
  carrier: string
}

/**
 * Records a tracked consignment on a parcel, or corrects one. A parcel can
 * carry several — three boxes, or a freight PRO number covering a pallet —
 * and each travels on its own carrier status.
 *
 * Shared by the operator's order page and the seller's. Headless: the caller
 * owns the form and the submit, so each panel keeps its own mutation, while
 * the carrier field's contract lives here — the value stored is the carrier's
 * key rather than its display name, and anything off the list stays as typed
 * because a forwarder's own name has to be enterable.
 */
export function DeliveryFormDialog({
  form,
  open,
  onOpenChange,
  editing,
  carrierKeys,
  carrierLabel,
  onSubmit,
  pending = false,
}: {
  form: UseFormReturn<DeliveryFormFields>
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Correcting an existing consignment rather than adding one. */
  editing: boolean
  carrierKeys: string[]
  carrierLabel: (key: string) => string
  onSubmit: (values: DeliveryFormFields) => void | Promise<void>
  pending?: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form
          onSubmit={(event) => {
            // The order page renders its cards inside their own forms — without
            // stopping the bubble the browser submits the outer one.
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
        >
          <DialogHeader>
            <DialogTitle>
              {editing
                ? t('admin.orders.detail.fulfillments.edit_tracking_title')
                : t('admin.orders.detail.fulfillments.add_tracking_title')}
            </DialogTitle>
            <DialogDescription>
              {t('admin.orders.detail.fulfillments.tracking_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody className="flex flex-col gap-4">
            {errors.root?.message && (
              <p className="text-destructive text-sm" role="alert">
                {errors.root.message}
              </p>
            )}

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="delivery-tracking-number">
                  {t('admin.orders.fulfill.tracking_label')}
                </FieldLabel>
                <Input
                  id="delivery-tracking-number"
                  placeholder={t('admin.orders.fulfill.tracking_placeholder')}
                  aria-invalid={!!errors.tracking_number}
                  {...form.register('tracking_number')}
                />
                <FieldError errors={[errors.tracking_number]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="delivery-carrier">
                  {t('admin.orders.detail.fulfillments.carrier_label')}
                </FieldLabel>
                <Controller
                  control={form.control}
                  name="carrier"
                  render={({ field }) => (
                    <Combobox
                      items={carrierKeys}
                      value={field.value}
                      onValueChange={(value: string | null) => field.onChange(value ?? '')}
                      itemToStringLabel={carrierLabel}
                    >
                      <ComboboxButtonTrigger id="delivery-carrier" onBlur={field.onBlur}>
                        {field.value ? (
                          <ComboboxValue />
                        ) : (
                          <ComboboxTriggerPlaceholder>
                            {t('admin.orders.detail.fulfillments.carrier_auto')}
                          </ComboboxTriggerPlaceholder>
                        )}
                      </ComboboxButtonTrigger>
                      <ComboboxContent>
                        <ComboboxSearch
                          placeholder={t('admin.orders.detail.fulfillments.carrier_search')}
                        />
                        <ComboboxEmpty>{t('admin.common.no_results')}</ComboboxEmpty>
                        <ComboboxList>
                          {(value: string) => (
                            <ComboboxItem key={value} value={value}>
                              {carrierLabel(value)}
                            </ComboboxItem>
                          )}
                        </ComboboxList>
                      </ComboboxContent>
                    </Combobox>
                  )}
                />
              </Field>
            </div>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
