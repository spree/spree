import {
  CurrencySelect,
  PageHeader,
  StoreDatePicker,
  useStockLocations,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
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
import { useCreatePurchaseOrder } from '../../../../../hooks/use-purchase-orders'
import { useSuppliers } from '../../../../../hooks/use-suppliers'

export const Route = createFileRoute('/_authenticated/$storeId/products/purchase-orders/new')({
  component: NewPurchaseOrderPage,
})

function NewPurchaseOrderPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreatePurchaseOrder()
  const { data: suppliers } = useSuppliers({ limit: 100 })
  const { data: stockLocations } = useStockLocations({ limit: 100 })

  const supplierOptions = suppliers?.data ?? []
  const locations = stockLocations?.data ?? []

  const [supplierId, setSupplierId] = useState('')
  const [destinationId, setDestinationId] = useState('')
  const [currency, setCurrency] = useState<string | undefined>(undefined)
  const [expectedAt, setExpectedAt] = useState<string | undefined>(undefined)
  const [reference, setReference] = useState('')
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<VariantLine[]>([])

  const canSubmit = !!supplierId && !!destinationId && lines.every((line) => line.quantity > 0)

  async function handleSubmit() {
    if (!canSubmit) return

    const purchaseOrder = await createMutation.mutateAsync({
      supplier_id: supplierId,
      destination_location_id: destinationId,
      currency,
      expected_at: expectedAt,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
      items: lines.map((line) => ({
        variant_id: line.variant.id,
        quantity_ordered: line.quantity,
        unit_cost: line.unitCost,
      })),
    })

    navigate({
      to: '/$storeId/products/purchase-orders/$purchaseOrderId',
      params: { storeId, purchaseOrderId: purchaseOrder.id },
    })
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <PageHeader title={t('admin.purchase_orders.new_title')} backTo="products/purchase-orders" />

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.purchase_orders.details_title')}</CardTitle>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="supplier">
                {t('admin.purchase_orders.fields.supplier')}
              </FieldLabel>
              <Select value={supplierId} onValueChange={setSupplierId}>
                <SelectTrigger id="supplier">
                  <SelectValue placeholder={t('admin.purchase_orders.fields.supplier_placeholder')}>
                    {(value) =>
                      supplierOptions.find((s) => s.id === value)?.name ?? (value as string)
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {supplierOptions.map((supplier) => (
                    <SelectItem key={supplier.id} value={supplier.id}>
                      {supplier.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel htmlFor="destination">
                {t('admin.purchase_orders.fields.destination')}
              </FieldLabel>
              <Select value={destinationId} onValueChange={setDestinationId}>
                <SelectTrigger id="destination">
                  <SelectValue
                    placeholder={t('admin.purchase_orders.fields.destination_placeholder')}
                  >
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
              <FieldLabel htmlFor="currency">
                {t('admin.purchase_orders.fields.currency')}
              </FieldLabel>
              {/* A foreign-currency purchase order is legitimate; leaving
                  this alone takes the store's own currency. */}
              <CurrencySelect id="currency" value={currency} onChange={setCurrency} />
            </Field>

            <Field>
              <FieldLabel>{t('admin.purchase_orders.fields.expected_at')}</FieldLabel>
              {/* A calendar date, not an instant: the day the supplier
                  promised means the same day in every timezone. */}
              <StoreDatePicker
                value={expectedAt}
                onChange={(value) => setExpectedAt(value ?? undefined)}
                placeholder={t('admin.purchase_orders.fields.expected_at_placeholder')}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="reference">
                {t('admin.purchase_orders.fields.reference')}
              </FieldLabel>
              <Input
                id="reference"
                placeholder={t('admin.purchase_orders.fields.reference_placeholder')}
                value={reference}
                onChange={(event) => setReference(event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="notes">{t('admin.purchase_orders.fields.notes')}</FieldLabel>
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
          <CardTitle>{t('admin.purchase_orders.items_title')}</CardTitle>
        </CardHeader>
        <CardContent>
          <VariantLineEditor
            lines={lines}
            onChange={setLines}
            currency={currency}
            quantityLabel={t('admin.purchase_orders.columns.quantity_ordered')}
            withCost
          />
        </CardContent>
      </Card>

      <div className="flex justify-end gap-2">
        <Button
          type="button"
          variant="outline"
          onClick={() =>
            navigate({ to: '/$storeId/products/purchase-orders', params: { storeId } })
          }
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
            : t('admin.purchase_orders.actions.create_draft')}
        </Button>
      </div>
    </div>
  )
}
