import type { Supplier } from '@spree/admin-sdk'
import {
  CurrencySelect,
  PageHeader,
  ResourceCombobox,
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
  FieldDescription,
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
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { supplierAutocompleteProps } from '../../hooks/use-suppliers'
import { SupplierSheet } from './supplier-sheet'
import { type VariantLine, VariantLineEditor } from './variant-line-editor'

export interface PurchaseOrderFormValues {
  supplierId: string
  destinationId: string
  currency?: string
  expectedAt?: string
  reference: string
  notes: string
  lines: VariantLine[]
}

export const EMPTY_PURCHASE_ORDER: PurchaseOrderFormValues = {
  supplierId: '',
  destinationId: '',
  currency: undefined,
  expectedAt: undefined,
  reference: '',
  notes: '',
  lines: [],
}

/**
 * What a draft purchase order is made of, for the screen that opens one and
 * the screen that corrects it.
 *
 * Shared because the two are the same form: an order is editable for exactly
 * as long as it is a draft, so "create" and "edit" differ only in where the
 * values start and what the button says.
 */
export function PurchaseOrderForm({
  initial,
  title,
  backTo,
  currencyLocked = false,
  submitLabel,
  pendingLabel,
  pending,
  onSubmit,
  onCancel,
}: {
  initial: PurchaseOrderFormValues
  /** Page title; the form owns the header so its actions sit with the others. */
  title: string
  /** Where the header's back arrow goes — the list, or the order being edited. */
  backTo: string
  /**
   * Fix the currency. Every line cost is denominated in it, so changing it on
   * a saved order would silently reprice the whole document.
   */
  currencyLocked?: boolean
  submitLabel: string
  pendingLabel: string
  pending: boolean
  onSubmit: (values: PurchaseOrderFormValues) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const { data: stockLocations } = useStockLocations({ limit: 100 })
  const locations = stockLocations?.data ?? []
  const locationItems = locations.map((location) => ({ value: location.id, label: location.name }))

  const [supplierId, setSupplierId] = useState(initial.supplierId)
  const [destinationId, setDestinationId] = useState(initial.destinationId)
  const [currency, setCurrency] = useState<string | undefined>(initial.currency)
  const [expectedAt, setExpectedAt] = useState<string | undefined>(initial.expectedAt)
  const [reference, setReference] = useState(initial.reference)
  const [notes, setNotes] = useState(initial.notes)
  const [lines, setLines] = useState<VariantLine[]>(initial.lines)
  const [creatingSupplier, setCreatingSupplier] = useState(false)
  const [pickerOpen, setPickerOpen] = useState(false)

  // A cleared cost input is not zero — it is nothing, which the server rejects
  // field-by-field. `Number('')` is 0 and finite, so the emptiness has to be
  // checked before the number is.
  const hasCost = (value?: string) => {
    const trimmed = value?.trim()
    return !!trimmed && Number.isFinite(Number(trimmed)) && Number(trimmed) >= 0
  }

  const canSubmit =
    !!supplierId &&
    !!destinationId &&
    lines.every((line) => line.quantity > 0 && hasCost(line.unitCost))

  const detailsCard = (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.purchase_orders.details_title')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="supplier">{t('admin.purchase_orders.fields.supplier')}</FieldLabel>
            {/* Searchable rather than a capped list: a wholesaler can hold
                more suppliers than one page of a Select would show, and a
                Select says nothing about the ones it left out. */}
            <ResourceCombobox<Supplier>
              {...supplierAutocompleteProps('purchase-order-supplier-picker')}
              id="supplier"
              value={supplierId}
              onChange={(id) => setSupplierId(id ?? '')}
              placeholder={t('admin.purchase_orders.fields.supplier_placeholder')}
              // Buying from someone new is part of raising the order, not a
              // detour through another screen — so it sits in the dropdown the
              // merchant already opened looking for them.
              action={{
                label: t('admin.suppliers.new_title'),
                onSelect: () => setCreatingSupplier(true),
              }}
            />
          </Field>

          <Field>
            <FieldLabel htmlFor="destination">
              {t('admin.purchase_orders.fields.destination')}
            </FieldLabel>
            {/* `items` rather than a render-prop: Base UI resolves the trigger
                label from it, and a render-prop suppresses the placeholder
                while nothing is chosen. */}
            <Select items={locationItems} value={destinationId} onValueChange={setDestinationId}>
              <SelectTrigger id="destination">
                <SelectValue
                  placeholder={t('admin.purchase_orders.fields.destination_placeholder')}
                />
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
            <FieldLabel htmlFor="currency">{t('admin.purchase_orders.fields.currency')}</FieldLabel>
            {/* A foreign-currency purchase order is legitimate; leaving
                this alone takes the store's own currency. */}
            <CurrencySelect
              id="currency"
              value={currency}
              onChange={setCurrency}
              disabled={currencyLocked}
            />
            {currencyLocked && (
              <FieldDescription>
                {t('admin.purchase_orders.fields.currency_locked')}
              </FieldDescription>
            )}
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
            <Textarea id="notes" value={notes} onChange={(event) => setNotes(event.target.value)} />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  )

  const itemsCard = (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>{t('admin.purchase_orders.items_title')}</CardTitle>
        {lines.length > 0 && (
          <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.inventory_lines.add_label')}
          </Button>
        )}
      </CardHeader>
      <CardContent>
        {/* No warehouse filter, unlike a transfer: buying stock in is how a
            merchant gets what they do not have. */}
        <VariantLineEditor
          lines={lines}
          onChange={setLines}
          currency={currency}
          quantityLabel={t('admin.purchase_orders.columns.quantity_ordered')}
          withCost
          pickerOpen={pickerOpen}
          onPickerOpenChange={setPickerOpen}
        />
      </CardContent>
    </Card>
  )

  return (
    <>
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
                  onClick={() =>
                    onSubmit({
                      supplierId,
                      destinationId,
                      currency,
                      expectedAt,
                      reference,
                      notes,
                      lines,
                    })
                  }
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

      {creatingSupplier && (
        <SupplierSheet
          open
          onOpenChange={(open) => !open && setCreatingSupplier(false)}
          onCreated={(supplier) => setSupplierId(supplier.id)}
        />
      )}
    </>
  )
}
