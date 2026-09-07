import { PageHeader, useStockLocations } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  type VariantLine,
  VariantLineEditor,
} from '../../../../../components/spree/variant-line-editor'
import { useCreateStockTransfer } from '../../../../../hooks/use-stock-transfers'

export const Route = createFileRoute('/_authenticated/$storeId/products/transfers/new')({
  component: NewStockTransferPage,
})

function NewStockTransferPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateStockTransfer()
  const { data: stockLocations } = useStockLocations({ limit: 100 })
  const locations = stockLocations?.data ?? []

  const [sourceId, setSourceId] = useState('')
  const [destinationId, setDestinationId] = useState('')
  const [reference, setReference] = useState('')
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<VariantLine[]>([])

  const sameLocation = !!sourceId && sourceId === destinationId
  const canSubmit =
    !!sourceId && !!destinationId && !sameLocation && lines.every((line) => line.quantity > 0)

  async function handleSubmit() {
    if (!canSubmit) return

    const transfer = await createMutation.mutateAsync({
      source_location_id: sourceId,
      destination_location_id: destinationId,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
      items: lines.map((line) => ({
        variant_id: line.variant.id,
        quantity_shipped: line.quantity,
      })),
    })

    navigate({
      to: '/$storeId/products/transfers/$transferId',
      params: { storeId, transferId: transfer.id },
    })
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <PageHeader title={t('admin.stock_transfers.new_title')} backTo="products/transfers" />

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.stock_transfers.details_title')}</CardTitle>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="source">{t('admin.stock_transfers.fields.source')}</FieldLabel>
              <Select value={sourceId} onValueChange={setSourceId}>
                <SelectTrigger id="source">
                  <SelectValue placeholder={t('admin.stock_transfers.fields.source_placeholder')}>
                    {(value) => locations.find((l) => l.id === value)?.name ?? (value as string)}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {locations.map((location) => (
                    <SelectItem key={location.id} value={location.id}>
                      {location.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel htmlFor="destination">
                {t('admin.stock_transfers.fields.destination')}
              </FieldLabel>
              <Select value={destinationId} onValueChange={setDestinationId}>
                <SelectTrigger id="destination">
                  <SelectValue
                    placeholder={t('admin.stock_transfers.fields.destination_placeholder')}
                  >
                    {(value) => locations.find((l) => l.id === value)?.name ?? (value as string)}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {locations
                    .filter((location) => location.id !== sourceId)
                    .map((location) => (
                      <SelectItem key={location.id} value={location.id}>
                        {location.name}
                      </SelectItem>
                    ))}
                </SelectContent>
              </Select>
              {sameLocation && (
                <FieldError>{t('admin.stock_transfers.errors.same_location')}</FieldError>
              )}
            </Field>

            <Field>
              <FieldLabel htmlFor="reference">
                {t('admin.stock_transfers.fields.reference')}
              </FieldLabel>
              <Input
                id="reference"
                placeholder={t('admin.stock_transfers.fields.reference_placeholder')}
                value={reference}
                onChange={(event) => setReference(event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="notes">{t('admin.stock_transfers.fields.notes')}</FieldLabel>
              <Textarea
                id="notes"
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
              />
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.stock_transfers.items_title')}</CardTitle>
        </CardHeader>
        <CardContent>
          {/* A draft may open empty and gain lines as the merchant packs, so
              there is nothing to enforce here. */}
          <VariantLineEditor
            lines={lines}
            onChange={setLines}
            quantityLabel={t('admin.stock_transfers.columns.quantity_shipped')}
          />
        </CardContent>
      </Card>

      <div className="flex justify-end gap-2">
        <Button
          type="button"
          variant="outline"
          onClick={() => navigate({ to: '/$storeId/products/transfers', params: { storeId } })}
        >
          {t('admin.actions.cancel')}
        </Button>
        <Button
          type="button"
          onClick={handleSubmit}
          disabled={!canSubmit || createMutation.isPending}
        >
          {createMutation.isPending
            ? t('admin.actions.creating')
            : t('admin.stock_transfers.actions.create_draft')}
        </Button>
      </div>
    </div>
  )
}
