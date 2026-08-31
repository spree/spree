import { CurrencySelect, normalizeQuantityRule, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldDescription,
  FieldError,
  FieldLabel,
  Input,
  TableCell,
  TableHead,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@spree/dashboard-ui'
import { InfoIcon, PlusIcon, XIcon } from 'lucide-react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type {
  CatalogFormValues,
  OrderMinimumEntry,
  StagedProductTerms,
} from '../../schemas/catalog'

/**
 * A term's explanation, on the label rather than under the field: these
 * rules are easy to confuse with one another (an order multiple is a step
 * size, not a divisor of the total) and a merchant setting one needs the
 * distinction where they are reading, not in a paragraph below.
 */
function TermHelp({ text }: { text: string }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          // A cursor-help affordance, not an action: it opens nothing and
          // must not take a tab stop away from the field it describes.
          tabIndex={-1}
          className="cursor-help text-muted-foreground"
          aria-hidden="true"
        >
          <InfoIcon className="size-3.5" />
        </button>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{text}</TooltipContent>
    </Tooltip>
  )
}

/**
 * How much buyers on this agreement must order: the catalog-wide default,
 * and the least a whole order must come to in each currency.
 *
 * Per-product exceptions are NOT here — they live as cells on the assortment
 * rows, where the products already are. A second product list in a sidebar
 * duplicated the one beside it and had nowhere to put two inputs a row
 * (docs/plans/6.0-b2b-quantity-rules.md).
 *
 * Everything stages into the surrounding form, so the page's Save and
 * Discard govern it like any other field.
 */
export function CatalogTermsCard({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const errors = form.formState.errors

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.terms.title')}</CardTitle>
        <CardDescription>{t('admin.catalogs.terms.description')}</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        <div className="grid grid-cols-2 gap-3">
          <Field>
            <FieldLabel htmlFor="catalog-moq" className="flex items-center gap-1.5">
              {t('admin.fields.minimum_order_quantity.label')}
              <TermHelp text={t('admin.catalogs.terms.help.minimum')} />
            </FieldLabel>
            <Input
              id="catalog-moq"
              type="number"
              min={1}
              step={1}
              disabled={!canEdit}
              aria-invalid={!!errors.minimum_order_quantity}
              placeholder={t('admin.catalogs.terms.no_rule_placeholder')}
              {...form.register('minimum_order_quantity')}
            />
            {errors.minimum_order_quantity && (
              <FieldError>{errors.minimum_order_quantity.message}</FieldError>
            )}
          </Field>

          <Field>
            <FieldLabel htmlFor="catalog-multiple" className="flex items-center gap-1.5">
              {t('admin.fields.order_multiple.label')}
              <TermHelp text={t('admin.catalogs.terms.help.multiple')} />
            </FieldLabel>
            <Input
              id="catalog-multiple"
              type="number"
              min={1}
              step={1}
              disabled={!canEdit}
              aria-invalid={!!errors.order_multiple}
              placeholder={t('admin.catalogs.terms.no_rule_placeholder')}
              {...form.register('order_multiple')}
            />
            {errors.order_multiple && <FieldError>{errors.order_multiple.message}</FieldError>}
          </Field>
        </div>
        <FieldDescription>{t('admin.catalogs.terms.default_help')}</FieldDescription>

        <OrderMinimums form={form} canEdit={canEdit} />
      </CardContent>
    </Card>
  )
}

/** One row per currency — never one amount with a currency beside it. */
function OrderMinimums({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const { store } = useStore()
  const rows: OrderMinimumEntry[] = form.watch('order_minimums') ?? []

  function update(next: OrderMinimumEntry[]) {
    form.setValue('order_minimums', next, { shouldDirty: true })
  }

  const usedCurrencies = rows.map((row) => row.currency)
  const nextCurrency =
    [store?.default_currency, ...(store?.supported_currencies ?? [])]
      .filter((code): code is string => !!code)
      .find((code) => !usedCurrencies.includes(code)) ?? ''

  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="flex items-center gap-1.5 font-medium text-sm">
            {t('admin.catalogs.terms.minimums_title')}
            <TermHelp text={t('admin.catalogs.terms.help.order_minimum')} />
          </h3>
          <p className="text-muted-foreground text-sm">
            {t('admin.catalogs.terms.minimums_description')}
          </p>
        </div>
        {canEdit && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={!nextCurrency}
            onClick={() => update([...rows, { currency: nextCurrency, amount: '' }])}
          >
            <PlusIcon className="size-4" />
            {t('admin.actions.add')}
          </Button>
        )}
      </div>

      {rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">{t('admin.catalogs.terms.minimums_empty')}</p>
      ) : (
        <div className="flex flex-col gap-2">
          {rows.map((row, index) => {
            const duplicate = usedCurrencies.indexOf(row.currency) !== index
            const amountValid = !row.amount.trim() || Number(row.amount) > 0

            return (
              <div key={row.currency} className="flex flex-col gap-1">
                <div className="flex items-center gap-2">
                  <div className="w-32 shrink-0">
                    <CurrencySelect
                      value={row.currency}
                      onChange={(currency) =>
                        update(rows.map((r, i) => (i === index ? { ...r, currency } : r)))
                      }
                    />
                  </div>
                  <Input
                    type="number"
                    min="0"
                    step="0.01"
                    disabled={!canEdit}
                    aria-invalid={!amountValid || duplicate}
                    aria-label={t('admin.catalogs.terms.minimum_amount_label')}
                    placeholder={t('admin.catalogs.terms.minimum_amount_label')}
                    value={row.amount}
                    onChange={(event) =>
                      update(
                        rows.map((r, i) =>
                          i === index ? { ...r, amount: event.target.value } : r,
                        ),
                      )
                    }
                  />
                  {canEdit && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label={t('admin.actions.remove')}
                      onClick={() => update(rows.filter((_, i) => i !== index))}
                    >
                      <XIcon className="size-4" />
                    </Button>
                  )}
                </div>
                {duplicate && (
                  <FieldError>{t('admin.catalogs.terms.validation.currency_taken')}</FieldError>
                )}
                {!amountValid && (
                  <FieldError>{t('admin.catalogs.terms.validation.positive_amount')}</FieldError>
                )}
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}

/**
 * The two term cells a catalog adds to each assortment row. Blank means the
 * product uses the catalog default, which shows as the placeholder so the
 * inherited value stays visible; `mixed` marks a product whose variants
 * disagree, and typing over it sets them all.
 */
export function catalogTermColumns({
  form,
  canEdit,
  headers,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
  headers: {
    /** Short column heading. */
    minimum: string
    multiple: string
    /** The full field name, kept as the input's accessible label. */
    minimumLabel: string
    multipleLabel: string
    /** What the term means, shown from the column heading. */
    minimumHelp: string
    multipleHelp: string
    mixed: string
    defaultHint: string
  }
}) {
  const terms = form.watch('staged_terms') ?? {}
  const catalogMinimum = form.watch('minimum_order_quantity')?.trim()
  const catalogMultiple = form.watch('order_multiple')?.trim()

  function set(
    productId: string,
    field: 'minimum_order_quantity' | 'order_multiple',
    value: string,
  ) {
    const current = terms[productId] ?? { minimum_order_quantity: '', order_multiple: '' }
    form.setValue(
      'staged_terms',
      // Typing clears `mixed`: the merchant is stating one pair for the
      // whole product, which is what the save then writes to every variant.
      { ...terms, [productId]: { ...current, [field]: value, mixed: false } },
      { shouldDirty: true },
    )
  }

  return {
    // The shared table's own cells rather than hand-rolled ones: TableHead
    // carries the header's rule and background, TableCell the row border, so
    // raw elements read as a separate block that ignores the row hover.
    headers: (
      <>
        <TableHead className="w-32">
          <span className="flex items-center gap-1.5">
            {headers.minimum}
            <TermHelp text={headers.minimumHelp} />
          </span>
        </TableHead>
        <TableHead className="w-32">
          <span className="flex items-center gap-1.5">
            {headers.multiple}
            <TermHelp text={headers.multipleHelp} />
          </span>
        </TableHead>
      </>
    ),
    renderCells: (row: { id: string; pending?: 'added' | 'removed' }) => {
      const entry = terms[row.id]
      // A row on its way out takes its terms with it, so editing them is
      // meaningless — and the struck-through row already says so.
      const disabled = !canEdit || row.pending === 'removed'

      return (
        <>
          <TableCell>
            <Input
              type="number"
              min={1}
              step={1}
              disabled={disabled}
              aria-label={headers.minimumLabel}
              placeholder={entry?.mixed ? headers.mixed : catalogMinimum || headers.defaultHint}
              value={entry?.minimum_order_quantity ?? ''}
              onChange={(event) => set(row.id, 'minimum_order_quantity', event.target.value)}
              className="h-8"
            />
          </TableCell>
          <TableCell>
            <Input
              type="number"
              min={1}
              step={1}
              disabled={disabled}
              aria-label={headers.multipleLabel}
              placeholder={entry?.mixed ? headers.mixed : catalogMultiple || headers.defaultHint}
              value={entry?.order_multiple ?? ''}
              onChange={(event) => set(row.id, 'order_multiple', event.target.value)}
              className="h-8"
            />
          </TableCell>
        </>
      )
    },
  }
}

/** The API's product terms as the form holds them. */
export function termsToFormValues(
  terms: Array<{
    product_id: string
    minimum_order_quantity?: number | null
    order_multiple?: number | null
    mixed?: boolean
  }>,
): StagedProductTerms {
  return Object.fromEntries(
    terms.map((term) => [
      term.product_id,
      {
        minimum_order_quantity: term.minimum_order_quantity?.toString() ?? '',
        order_multiple: term.order_multiple?.toString() ?? '',
        mixed: term.mixed,
      },
    ]),
  )
}

/** Terms as the API takes them, with blanks meaning "clear this product". */
export function stagedTermsToParams(
  terms: Record<string, { minimum_order_quantity: string; order_multiple: string }>,
) {
  return Object.fromEntries(
    Object.entries(terms).map(([productId, entry]) => [
      productId,
      {
        minimum_order_quantity: normalizeQuantityRule(entry.minimum_order_quantity),
        order_multiple: normalizeQuantityRule(entry.order_multiple),
      },
    ]),
  )
}
