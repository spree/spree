import type { ReactNode } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
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
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '../ui/input-group'

/** The form shape both panels bind for a label bought elsewhere. */
export type LabelUploadFields = {
  tracking_number: string
  carrier: string
  cost: string
}

/**
 * Records a label the merchant bought elsewhere — postage from a carrier's
 * own site, a 3PL's PDF — so the parcel still has its file, its tracking
 * number and what it cost, with no carrier account connected.
 *
 * Shared by the operator's order page and the seller's; on the seller branch
 * it is the only way a label arrives, since buying one runs through the
 * marketplace's carrier account.
 *
 * The file field comes in as a slot: uploading needs an API client, which is
 * each panel's own.
 */
export function LabelUploadDialog({
  form,
  open,
  onOpenChange,
  fileField,
  carrierKeys,
  carrierLabel,
  currency,
  onSubmit,
  pending = false,
}: {
  form: UseFormReturn<LabelUploadFields>
  open: boolean
  onOpenChange: (open: boolean) => void
  fileField: ReactNode
  carrierKeys: string[]
  carrierLabel: (key: string) => string
  /** Shown beside the cost, when the caller knows which currency it is in. */
  currency?: string
  onSubmit: (values: LabelUploadFields) => void | Promise<void>
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
            <DialogTitle>{t('admin.orders.detail.fulfillments.upload_label_title')}</DialogTitle>
            <DialogDescription>
              {t('admin.orders.detail.fulfillments.upload_label_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody className="flex flex-col gap-4">
            {errors.root?.message && (
              <p className="text-destructive text-sm" role="alert">
                {errors.root.message}
              </p>
            )}

            <Field>
              <FieldLabel>{t('admin.orders.detail.fulfillments.upload_label_file')}</FieldLabel>
              {fileField}
            </Field>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="label-tracking-number">
                  {t('admin.orders.fulfill.tracking_label')}
                </FieldLabel>
                <Input
                  id="label-tracking-number"
                  placeholder={t('admin.orders.fulfill.tracking_placeholder')}
                  aria-invalid={!!errors.tracking_number}
                  {...form.register('tracking_number')}
                />
                <FieldError errors={[errors.tracking_number]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="label-cost">
                  {t('admin.orders.detail.fulfillments.upload_label_cost')}
                </FieldLabel>
                <InputGroup>
                  {currency && (
                    <InputGroupAddon>
                      <InputGroupText>{currency}</InputGroupText>
                    </InputGroupAddon>
                  )}
                  <InputGroupInput
                    id="label-cost"
                    type="number"
                    step="0.01"
                    min="0"
                    {...form.register('cost')}
                  />
                </InputGroup>
                <FieldError errors={[errors.cost]} />
              </Field>
            </div>

            <Field>
              <FieldLabel htmlFor="label-carrier">
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
                    <ComboboxButtonTrigger id="label-carrier" onBlur={field.onBlur}>
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
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending
                ? t('admin.actions.saving')
                : t('admin.orders.detail.fulfillments.upload_label')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
