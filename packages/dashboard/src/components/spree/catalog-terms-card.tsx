import type { CatalogOrderMinimum, CatalogQuantityRule, Variant } from '@spree/admin-sdk'
import {
  adminClient,
  CurrencySelect,
  normalizeQuantityRule,
  ResourceCombobox,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Pagination,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon, XIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useCatalogQuantityRules,
  useCreateCatalogOrderMinimum,
  useCreateCatalogQuantityRule,
  useDeleteCatalogOrderMinimum,
  useDeleteCatalogQuantityRule,
} from '../../hooks/use-catalogs'
import type { CatalogFormValues } from '../../schemas/catalog'

/**
 * What this agreement lets a buyer order, and what it requires the whole
 * order to reach. Three grains in one card because they answer one merchant
 * question — "how much must they buy?" — at different scopes: the catalog's
 * own default, the per-SKU exceptions, and the order-level threshold.
 *
 * The catalog-wide pair rides the page form and saves with everything else;
 * the rows below write immediately, since each is its own record
 * (docs/plans/6.0-b2b-quantity-rules.md).
 */
export function CatalogTermsCard({
  catalogId,
  form,
  orderMinimums,
  canEdit,
}: {
  catalogId: string
  form: UseFormReturn<CatalogFormValues>
  orderMinimums: CatalogOrderMinimum[]
  canEdit: boolean
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.catalogs.terms.title')}</CardTitle>
        <CardDescription>{t('admin.catalogs.terms.description')}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-8">
        <CatalogDefaultFields form={form} canEdit={canEdit} />
        <OrderMinimumsSection
          catalogId={catalogId}
          orderMinimums={orderMinimums}
          canEdit={canEdit}
        />
        <QuantityRulesSection catalogId={catalogId} canEdit={canEdit} />
      </CardContent>
    </Card>
  )
}

/** The catalog-wide default — part of the page form, saved with it. */
function CatalogDefaultFields({
  form,
  canEdit,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const errors = form.formState.errors

  return (
    <FieldGroup className="sm:grid sm:grid-cols-2 sm:gap-4">
      <Field>
        <FieldLabel htmlFor="catalog-moq">
          {t('admin.fields.minimum_order_quantity.label')}
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
        <FieldDescription>{t('admin.fields.minimum_order_quantity.help')}</FieldDescription>
        {errors.minimum_order_quantity && (
          <FieldError>{errors.minimum_order_quantity.message}</FieldError>
        )}
      </Field>

      <Field>
        <FieldLabel htmlFor="catalog-multiple">{t('admin.fields.order_multiple.label')}</FieldLabel>
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
        <FieldDescription>{t('admin.fields.order_multiple.help')}</FieldDescription>
        {errors.order_multiple && <FieldError>{errors.order_multiple.message}</FieldError>}
      </Field>
    </FieldGroup>
  )
}

/** One row per currency — never one amount with a currency beside it. */
function OrderMinimumsSection({
  catalogId,
  orderMinimums,
  canEdit,
}: {
  catalogId: string
  orderMinimums: CatalogOrderMinimum[]
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const [dialogOpen, setDialogOpen] = useState(false)
  const deleteMutation = useDeleteCatalogOrderMinimum(catalogId)

  async function handleDelete(minimum: CatalogOrderMinimum) {
    const confirmed = await confirm({
      title: t('admin.catalogs.terms.remove_minimum_title'),
      message: t('admin.catalogs.terms.remove_minimum_description', {
        currency: minimum.currency,
      }),
      confirmLabel: t('admin.actions.remove'),
      variant: 'destructive',
    })
    if (confirmed) await deleteMutation.mutateAsync(minimum.id).catch(() => undefined)
  }

  return (
    <section className="space-y-3">
      <header className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-medium">{t('admin.catalogs.terms.minimums_title')}</h3>
          <p className="text-muted-foreground text-sm">
            {t('admin.catalogs.terms.minimums_description')}
          </p>
        </div>
        {canEdit && (
          <Button type="button" variant="outline" size="sm" onClick={() => setDialogOpen(true)}>
            <PlusIcon />
            {t('admin.actions.add')}
          </Button>
        )}
      </header>

      {orderMinimums.length === 0 ? (
        <p className="text-muted-foreground text-sm">{t('admin.catalogs.terms.minimums_empty')}</p>
      ) : (
        <Table>
          <TableBody>
            {orderMinimums.map((minimum) => (
              <TableRow key={minimum.id}>
                <TableCell className="font-medium">{minimum.currency}</TableCell>
                <TableCell>{minimum.display_amount}</TableCell>
                <TableCell className="w-10 text-right">
                  {canEdit && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label={t('admin.actions.remove')}
                      onClick={() => handleDelete(minimum)}
                    >
                      <XIcon />
                    </Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <AddOrderMinimumDialog
        catalogId={catalogId}
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        usedCurrencies={orderMinimums.map((minimum) => minimum.currency)}
      />
    </section>
  )
}

function AddOrderMinimumDialog({
  catalogId,
  open,
  onOpenChange,
  usedCurrencies,
}: {
  catalogId: string
  open: boolean
  onOpenChange: (open: boolean) => void
  usedCurrencies: string[]
}) {
  const { t } = useTranslation()
  const { store } = useStore()
  const createMutation = useCreateCatalogOrderMinimum(catalogId)
  const [currency, setCurrency] = useState(store?.default_currency ?? 'USD')
  const [amount, setAmount] = useState('')

  const duplicate = usedCurrencies.includes(currency)
  // Never coerced: "12,50" parses as 12 in JavaScript too, and a minimum an
  // order can trivially clear is worse than one the merchant has to retype.
  const parsedAmount = /^\d+(\.\d{1,2})?$/.test(amount.trim()) ? Number(amount.trim()) : null
  const amountValid = parsedAmount !== null && parsedAmount > 0
  const showAmountError = amount.trim() !== '' && !amountValid

  async function handleSubmit() {
    if (!amountValid || duplicate) return

    await createMutation
      .mutateAsync({ currency, amount })
      .then(() => {
        setAmount('')
        onOpenChange(false)
      })
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.catalogs.terms.add_minimum_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel>{t('admin.fields.currency.label')}</FieldLabel>
              <CurrencySelect value={currency} onChange={setCurrency} />
              {duplicate && (
                <FieldError>{t('admin.catalogs.terms.validation.currency_taken')}</FieldError>
              )}
            </Field>
            <Field>
              <FieldLabel htmlFor="minimum-amount">
                {t('admin.catalogs.terms.minimum_amount_label')}
              </FieldLabel>
              <Input
                id="minimum-amount"
                inputMode="decimal"
                aria-invalid={showAmountError}
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
              />
              {showAmountError && (
                <FieldError>{t('admin.catalogs.terms.validation.positive_amount')}</FieldError>
              )}
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={createMutation.isPending || !amountValid || duplicate}
            onClick={handleSubmit}
          >
            {t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** The per-variant overrides, paged — an agreement may name thousands. */
function QuantityRulesSection({ catalogId, canEdit }: { catalogId: string; canEdit: boolean }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const [dialogOpen, setDialogOpen] = useState(false)
  const { data } = useCatalogQuantityRules(catalogId, page)
  const deleteMutation = useDeleteCatalogQuantityRule(catalogId)

  const rules = data?.data ?? []
  const lastPage = data?.meta?.pages ?? 1

  // Deleting the last row on the last page would otherwise strand the
  // merchant on an empty page while earlier ones still have rows.
  useEffect(() => {
    if (page > lastPage) setPage(lastPage)
  }, [page, lastPage])

  async function handleDelete(rule: CatalogQuantityRule) {
    const confirmed = await confirm({
      title: t('admin.catalogs.terms.remove_rule_title'),
      message: t('admin.catalogs.terms.remove_rule_description', {
        name: rule.product_name ?? rule.variant_sku ?? '',
      }),
      confirmLabel: t('admin.actions.remove'),
      variant: 'destructive',
    })
    if (confirmed) await deleteMutation.mutateAsync(rule.id).catch(() => undefined)
  }

  return (
    <section className="space-y-3">
      <header className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-medium">{t('admin.catalogs.terms.overrides_title')}</h3>
          <p className="text-muted-foreground text-sm">
            {t('admin.catalogs.terms.overrides_description')}
          </p>
        </div>
        {canEdit && (
          <Button type="button" variant="outline" size="sm" onClick={() => setDialogOpen(true)}>
            <PlusIcon />
            {t('admin.actions.add')}
          </Button>
        )}
      </header>

      {rules.length === 0 ? (
        <p className="text-muted-foreground text-sm">{t('admin.catalogs.terms.overrides_empty')}</p>
      ) : (
        <>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.catalogs.terms.product_column')}</TableHead>
                <TableHead>{t('admin.fields.minimum_order_quantity.label')}</TableHead>
                <TableHead>{t('admin.fields.order_multiple.label')}</TableHead>
                <TableHead className="w-10" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {rules.map((rule) => (
                <TableRow key={rule.id}>
                  <TableCell>
                    <span className="font-medium">{rule.product_name}</span>
                    {rule.options_text && (
                      <span className="text-muted-foreground"> · {rule.options_text}</span>
                    )}
                    {rule.variant_sku && (
                      <span className="text-muted-foreground block text-xs">
                        {rule.variant_sku}
                      </span>
                    )}
                  </TableCell>
                  <TableCell>{rule.minimum_order_quantity ?? '—'}</TableCell>
                  <TableCell>{rule.order_multiple ?? '—'}</TableCell>
                  <TableCell className="text-right">
                    {canEdit && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label={t('admin.actions.remove')}
                        onClick={() => handleDelete(rule)}
                      >
                        <XIcon />
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
          {data?.meta && <Pagination meta={data.meta} onPageChange={setPage} />}
        </>
      )}

      <AddQuantityRuleDialog catalogId={catalogId} open={dialogOpen} onOpenChange={setDialogOpen} />
    </section>
  )
}

function AddQuantityRuleDialog({
  catalogId,
  open,
  onOpenChange,
}: {
  catalogId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCatalogQuantityRule(catalogId)
  const [variantId, setVariantId] = useState('')
  const [minimum, setMinimum] = useState('')
  const [multiple, setMultiple] = useState('')

  // A row must state at least one field: an override that overrides nothing
  // is a half-filled form, and the server refuses it anyway. Each stated
  // field must also be usable — without checking here the request goes,
  // fails validation, and the dialog just sits there saying nothing.
  const minimumValid = !minimum.trim() || normalizeQuantityRule(minimum) !== null
  const multipleValid = !multiple.trim() || normalizeQuantityRule(multiple) !== null
  const statesSomething = !!minimum.trim() || !!multiple.trim()
  const canSubmit = statesSomething && minimumValid && multipleValid

  async function handleSubmit() {
    if (!variantId || !canSubmit) return

    await createMutation
      .mutateAsync({
        variant_id: variantId,
        minimum_order_quantity: normalizeQuantityRule(minimum),
        order_multiple: normalizeQuantityRule(multiple),
      })
      .then(() => {
        setVariantId('')
        setMinimum('')
        setMultiple('')
        onOpenChange(false)
      })
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.catalogs.terms.add_rule_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel>{t('admin.catalogs.terms.product_column')}</FieldLabel>
              <ResourceCombobox<Variant>
                queryKey="catalog-term-variants"
                search={(query) =>
                  adminClient.variants.list({ product_name_or_sku_cont: query, limit: 10 })
                }
                hydrate={(ids) => adminClient.variants.list({ id_in: ids, limit: ids.length })}
                getOptionLabel={(variant) =>
                  [variant.product_name, variant.options_text, variant.sku]
                    .filter(Boolean)
                    .join(' · ')
                }
                placeholder={t('admin.catalogs.terms.variant_placeholder')}
                emptyText={t('admin.catalogs.terms.variant_empty')}
                value={variantId || undefined}
                onChange={(id) => setVariantId(id ?? '')}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="rule-minimum">
                {t('admin.fields.minimum_order_quantity.label')}
              </FieldLabel>
              <Input
                id="rule-minimum"
                type="number"
                min={1}
                step={1}
                aria-invalid={!minimumValid}
                value={minimum}
                onChange={(event) => setMinimum(event.target.value)}
              />
              {!minimumValid && (
                <FieldError>{t('admin.catalogs.terms.validation.positive_integer')}</FieldError>
              )}
            </Field>
            <Field>
              <FieldLabel htmlFor="rule-multiple">
                {t('admin.fields.order_multiple.label')}
              </FieldLabel>
              <Input
                id="rule-multiple"
                type="number"
                min={1}
                step={1}
                aria-invalid={!multipleValid}
                value={multiple}
                onChange={(event) => setMultiple(event.target.value)}
              />
              {!multipleValid && (
                <FieldError>{t('admin.catalogs.terms.validation.positive_integer')}</FieldError>
              )}
              <FieldDescription>{t('admin.catalogs.terms.override_help')}</FieldDescription>
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={createMutation.isPending || !variantId || !canSubmit}
            onClick={handleSubmit}
          >
            {t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
