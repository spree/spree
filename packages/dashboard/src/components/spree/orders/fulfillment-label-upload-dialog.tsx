import { zodResolver } from '@hookform/resolvers/zod'
import {
  EMPTY_FILE_UPLOAD_VALUE,
  FileUploadField,
  type FileUploadValue,
  mapSpreeErrorsToForm,
} from '@spree/dashboard-core'
import {
  Button,
  Combobox,
  ComboboxButtonTrigger,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxSearch,
  ComboboxTriggerPlaceholder,
  ComboboxValue,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'

/** What a carrier label plausibly arrives as — mirrors the server allowlist. */
const LABEL_ACCEPT = 'application/pdf,image/png,text/plain'

const uploadSchema = z.object({
  tracking_number: z.string().min(1),
  carrier: z.string(),
  cost: z.string(),
})

type UploadFormValues = z.infer<typeof uploadSchema>

/**
 * Records a label the merchant bought elsewhere — postage from a carrier site,
 * a 3PL's PDF — so the parcel still has its file, its tracking number and what
 * it cost, with no carrier account connected.
 */
export function FulfillmentLabelUploadDialog({
  orderId,
  fulfillmentId,
  currency,
  open,
  onOpenChange,
}: {
  orderId: string
  fulfillmentId: string
  currency?: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { buyLabel } = useFulfillmentActions(orderId)
  const { data: carriersData } = useTrackingCarriers(open)

  // The registry's carriers, stored by key and shown by name. Anything it
  // does not know is still typeable — a forwarder's own name is a legal
  // carrier, and an empty value asks the server to detect one.
  const carrierOptions = (carriersData?.data ?? []).map((carrier) => ({
    value: carrier.id,
    label: carrier.name,
  }))

  const carrierLabel = (value: string) =>
    carrierOptions.find((option) => option.value === value)?.label ?? value

  const [file, setFile] = useState<FileUploadValue>(EMPTY_FILE_UPLOAD_VALUE)
  // The signed id does not exist until the upload resolves, so saving during
  // one would silently drop the file.
  const [uploading, setUploading] = useState(false)

  const form = useForm<UploadFormValues>({
    resolver: zodResolver(uploadSchema),
    defaultValues: { tracking_number: '', carrier: '', cost: '' },
  })

  async function onSubmit(values: UploadFormValues) {
    if (!file.signedId) {
      form.setError('root', { message: t('admin.orders.detail.fulfillments.upload_label_file') })
      return
    }

    try {
      await buyLabel.mutateAsync({
        fulfillmentId,
        file: file.signedId,
        tracking_number: values.tracking_number.trim(),
        carrier: values.carrier.trim() || undefined,
        cost: values.cost.trim() || undefined,
        currency: values.cost.trim() ? currency : undefined,
      })
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

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
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}

            <Field>
              <FieldLabel>{t('admin.orders.detail.fulfillments.upload_label_file')}</FieldLabel>
              <FileUploadField
                accept={LABEL_ACCEPT}
                value={file}
                onChange={setFile}
                onUploadingChange={setUploading}
                private
              />
            </Field>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="label-tracking-number">
                  {t('admin.orders.fulfill.tracking_label')}
                </FieldLabel>
                <Input
                  id="label-tracking-number"
                  placeholder={t('admin.orders.fulfill.tracking_placeholder')}
                  aria-invalid={!!form.formState.errors.tracking_number}
                  {...form.register('tracking_number')}
                />
                <FieldError errors={[form.formState.errors.tracking_number]} />
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
                <FieldError errors={[form.formState.errors.cost]} />
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
                    items={carrierOptions.map((option) => option.value)}
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
            <Button type="submit" disabled={buyLabel.isPending || uploading}>
              {buyLabel.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
