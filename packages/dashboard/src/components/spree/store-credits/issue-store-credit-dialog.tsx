import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer, StoreCredit } from '@spree/admin-sdk'
import {
  CurrencySelect,
  currencyParts,
  mapSpreeErrorsToForm,
  normalizeMoneyInput,
  ResourceCombobox,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Textarea,
} from '@spree/dashboard-ui'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCurrencyLocale } from '../../../hooks/use-currency-locale'
import { useCreateCustomerStoreCredit } from '../../../hooks/use-customer-store-credits'
import { customerAutocompleteProps } from '../../../hooks/use-customers'
import {
  type IssueStoreCreditFormValues,
  issueStoreCreditFormSchema,
} from '../../../schemas/store-credit'

/**
 * Issues a store credit. Opened from a customer profile it credits that
 * customer; opened without a `customerId` it asks which customer to credit.
 */
export function IssueStoreCreditDialog({
  customerId,
  open,
  onOpenChange,
  onIssued,
}: {
  customerId?: string
  open: boolean
  onOpenChange: (open: boolean) => void
  onIssued?: (credit: StoreCredit) => void
}) {
  const { t } = useTranslation()
  // Seed `currency` with the store default so the merchant doesn't have to
  // pick one explicitly — `CurrencySelect` displays it but no longer commits
  // it via onChange, so the form value needs to start populated.
  const { defaultCurrency } = useStore()
  const emptyValues = {
    customer_id: customerId ?? '',
    amount: '',
    currency: defaultCurrency,
    memo: '',
  }
  const form = useForm<IssueStoreCreditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(issueStoreCreditFormSchema) as any,
    defaultValues: emptyValues,
  })
  const { errors } = form.formState

  const mutation = useCreateCustomerStoreCredit()
  const localeForCurrency = useCurrencyLocale()
  const selectedCurrency = form.watch('currency')
  const { symbol } = currencyParts(selectedCurrency, localeForCurrency(selectedCurrency) || 'en')

  // Clear any prior submission state when the dialog re-opens so a fresh form
  // is presented (otherwise stale "Issue $20" values linger across opens).
  // biome-ignore lint/correctness/useExhaustiveDependencies: reset only on open
  useEffect(() => {
    if (open) form.reset(emptyValues)
  }, [open, form, defaultCurrency, customerId])

  // Switching currency re-displays the amount in the new currency's locale
  // format, so the value the merchant sees always matches the locale it will be
  // normalized under on submit. Without this, `25.00` typed under USD would be
  // re-read under EUR's `de` locale (where `.` groups thousands) and persist as
  // 2500. Canonicalize from the old locale, then swap to the new locale's
  // decimal separator.
  function handleCurrencyChange(
    next: string,
    field: { value: string; onChange: (v: string) => void },
  ) {
    const prev = field.value
    field.onChange(next)
    const raw = form.getValues('amount')?.trim()
    if (!raw) return
    const canonical = normalizeMoneyInput(raw, localeForCurrency(prev) || 'en')
    const { decimal } = currencyParts(next, localeForCurrency(next) || 'en')
    form.setValue('amount', decimal === '.' ? canonical : canonical.replace('.', decimal))
  }

  async function onSubmit(values: IssueStoreCreditFormValues) {
    try {
      const credit = await mutation.mutateAsync({
        customerId: values.customer_id,
        // Normalize the merchant's localized input (entered under the selected
        // currency's market locale) to the canonical `"1234.56"` the API
        // expects. The server never parses comma-vs-period.
        amount: normalizeMoneyInput(values.amount, localeForCurrency(values.currency) || 'en'),
        currency: values.currency,
        memo: values.memo || undefined,
      })
      onOpenChange(false)
      onIssued?.(credit)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.customers.detail.issue_credit')}</DialogTitle>
          <DialogDescription>
            {customerId
              ? t('admin.customers.detail.store_credit.add_description')
              : t('admin.store_credits.issue_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <FieldGroup>
              {!customerId && (
                <Field>
                  <FieldLabel htmlFor="sc-customer">
                    {t('admin.fields.customer_id.label')}
                  </FieldLabel>
                  <Controller
                    name="customer_id"
                    control={form.control}
                    render={({ field }) => (
                      <ResourceCombobox<Customer>
                        {...customerAutocompleteProps('store-credit-customer-picker')}
                        id="sc-customer"
                        value={field.value || undefined}
                        onChange={(id) => field.onChange(id ?? '')}
                      />
                    )}
                  />
                  <FieldError errors={[errors.customer_id]} />
                </Field>
              )}
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="sc-amount">
                    {t('admin.fields.store_credit.amount.label')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupAddon>
                      <InputGroupText>{symbol}</InputGroupText>
                    </InputGroupAddon>
                    <InputGroupInput
                      id="sc-amount"
                      type="text"
                      inputMode="decimal"
                      required
                      aria-invalid={!!errors.amount || undefined}
                      {...form.register('amount')}
                    />
                  </InputGroup>
                  <FieldError errors={[errors.amount]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="sc-currency">
                    {t('admin.fields.store_credit.currency.label')}
                  </FieldLabel>
                  <Controller
                    name="currency"
                    control={form.control}
                    render={({ field }) => (
                      <CurrencySelect
                        id="sc-currency"
                        value={field.value || ''}
                        onChange={(next) => handleCurrencyChange(next, field)}
                        required
                      />
                    )}
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="sc-memo">
                  {t('admin.fields.store_credit.memo.label')}
                </FieldLabel>
                <Textarea
                  id="sc-memo"
                  rows={3}
                  placeholder={t('admin.fields.store_credit.memo.placeholder')}
                  aria-invalid={!!errors.memo || undefined}
                  {...form.register('memo')}
                />
                <FieldError errors={[errors.memo]} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending
                ? t('admin.actions.saving')
                : t('admin.pages.customers.detail.issue_credit')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
