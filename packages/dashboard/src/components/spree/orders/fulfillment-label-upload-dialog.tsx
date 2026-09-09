import { zodResolver } from '@hookform/resolvers/zod'
import {
  EMPTY_FILE_UPLOAD_VALUE,
  FileUploadField,
  type FileUploadValue,
  LABEL_ACCEPT,
  type LabelUploadFormValues,
  labelUploadFormSchema,
  mapSpreeErrorsToForm,
} from '@spree/dashboard-core'
import { LabelUploadDialog } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'

/** Records a label the operator bought outside Spree. */
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

  const carriers = carriersData?.data ?? []
  const carrierKeys = carriers.map((carrier) => carrier.id)
  const carrierLabel = (value: string) =>
    carriers.find((carrier) => carrier.id === value)?.name ?? value

  const [file, setFile] = useState<FileUploadValue>(EMPTY_FILE_UPLOAD_VALUE)
  // The signed id does not exist until the upload resolves, so saving during
  // one would silently drop the file.
  const [uploading, setUploading] = useState(false)

  const form = useForm<LabelUploadFormValues>({
    resolver: zodResolver(labelUploadFormSchema),
    defaultValues: { tracking_number: '', carrier: '', cost: '' },
  })

  async function onSubmit(values: LabelUploadFormValues) {
    // Guarded here as well as on the server: submitting without one would
    // record a label with no file behind it.
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
    <LabelUploadDialog
      form={form}
      open={open}
      onOpenChange={onOpenChange}
      fileField={
        <FileUploadField
          accept={LABEL_ACCEPT}
          value={file}
          onChange={setFile}
          onUploadingChange={setUploading}
          private
        />
      }
      carrierKeys={carrierKeys}
      carrierLabel={carrierLabel}
      currency={currency}
      onSubmit={onSubmit}
      pending={buyLabel.isPending || uploading}
    />
  )
}
