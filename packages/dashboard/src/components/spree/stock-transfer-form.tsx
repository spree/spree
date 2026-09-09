import { PageHeader, useStockLocations } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { type VariantLine, VariantLineEditor } from './variant-line-editor'

export interface StockTransferFormValues {
  sourceId: string
  destinationId: string
  reference: string
  notes: string
  lines: VariantLine[]
}

export const EMPTY_STOCK_TRANSFER: StockTransferFormValues = {
  sourceId: '',
  destinationId: '',
  reference: '',
  notes: '',
  lines: [],
}

/**
 * What a draft transfer is made of, for the screen that opens one and the
 * screen that corrects it.
 *
 * Shared because the two are the same form: a transfer is editable for exactly
 * as long as it is a draft, so "create" and "edit" differ only in where the
 * values start and what the button says.
 */
export function StockTransferForm({
  initial,
  title,
  backTo,
  submitLabel,
  pendingLabel,
  pending,
  onSubmit,
  onCancel,
}: {
  initial: StockTransferFormValues
  /** Page title; the form owns the header so its actions sit with the others. */
  title: string
  /** Where the header's back arrow goes — the list, or the transfer being edited. */
  backTo: string
  submitLabel: string
  pendingLabel: string
  pending: boolean
  onSubmit: (values: StockTransferFormValues) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const { data: stockLocations } = useStockLocations({ limit: 100 })
  const locations = stockLocations?.data ?? []
  const locationItems = locations.map((location) => ({ value: location.id, label: location.name }))

  const [sourceId, setSourceId] = useState(initial.sourceId)
  const [destinationId, setDestinationId] = useState(initial.destinationId)
  const [reference, setReference] = useState(initial.reference)
  const [notes, setNotes] = useState(initial.notes)
  const [lines, setLines] = useState<VariantLine[]>(initial.lines)

  // Stock cannot move to where it already is.
  const destinationItems = locationItems.filter((item) => item.value !== sourceId)

  const sameLocation = !!sourceId && sourceId === destinationId
  // Lines were picked for the shelf they are leaving, so the source is fixed
  // once there are any: changing it would silently keep SKUs the new source
  // may hold none of. Emptying the list frees it again. Applies while creating
  // too — the picker filters by source there as well.
  const sourceLocked = lines.length > 0
  const canSubmit =
    !!sourceId && !!destinationId && !sameLocation && lines.every((line) => line.quantity > 0)

  const detailsCard = (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_transfers.details_title')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="source">{t('admin.stock_transfers.fields.source')}</FieldLabel>
            {/* `items` rather than a render-prop: Base UI resolves the trigger
                label from it, and a render-prop suppresses the placeholder
                while nothing is chosen. */}
            <Select
              items={locationItems}
              value={sourceId}
              onValueChange={setSourceId}
              disabled={sourceLocked}
            >
              <SelectTrigger id="source">
                <SelectValue placeholder={t('admin.stock_transfers.fields.source_placeholder')} />
              </SelectTrigger>
              <SelectContent>
                {locations.map((location) => (
                  <SelectItem key={location.id} value={location.id}>
                    {location.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {sourceLocked && (
              <FieldDescription>{t('admin.stock_transfers.fields.source_locked')}</FieldDescription>
            )}
          </Field>

          <Field>
            <FieldLabel htmlFor="destination">
              {t('admin.stock_transfers.fields.destination')}
            </FieldLabel>
            <Select items={destinationItems} value={destinationId} onValueChange={setDestinationId}>
              <SelectTrigger id="destination">
                <SelectValue
                  placeholder={t('admin.stock_transfers.fields.destination_placeholder')}
                />
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
            <Textarea id="notes" value={notes} onChange={(event) => setNotes(event.target.value)} />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  )

  const itemsCard = (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_transfers.items_title')}</CardTitle>
      </CardHeader>
      <CardContent>
        {/* A draft may hold no lines at all and gain them as the merchant
              packs, so there is nothing to enforce here. The picker offers only
              what the source can send and stays shut until one is chosen. */}
        <VariantLineEditor
          lines={lines}
          onChange={setLines}
          quantityLabel={t('admin.stock_transfers.columns.quantity_shipped')}
          stockLocationId={sourceId || null}
          requireStockLocation
        />
      </CardContent>
    </Card>
  )

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={title}
          backTo={backTo}
          actions={
            <>
              <Button type="button" variant="outline" onClick={onCancel}>
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="button"
                onClick={() => onSubmit({ sourceId, destinationId, reference, notes, lines })}
                disabled={!canSubmit || pending}
              >
                {pending ? pendingLabel : submitLabel}
              </Button>
            </>
          }
        />
      }
      main={itemsCard}
      sidebar={detailsCard}
    />
  )
}
