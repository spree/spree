import { zodResolver } from '@hookform/resolvers/zod'
import type { StoreCredit } from '@spree/admin-sdk'
import {
  CurrencySelect,
  currencyParts,
  mapSpreeErrorsToForm,
  normalizeMoneyInput,
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
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCurrencyLocale } from '../../../hooks/use-currency-locale'
import {
  type StoreCreditUpdateParams,
  useUpdateCustomerStoreCredit,
} from '../../../hooks/use-customer-store-credits'
import {
  type EditStoreCreditFormValues,
  editStoreCreditFormSchema,
} from '../../../schemas/store-credit'

export function EditStoreCreditDialog({
  customerId,
  credit,
  onOpenChange,
}: {
  customerId: string
  credit: StoreCredit
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // Server rejects amount changes once any of it has been used. Lock the
  // field so the merchant doesn't submit a value that will only come back
  // as a 422 store_credit_in_use.
  const amountLocked = Number(credit.amount_used ?? 0) > 0

  const localeForCurrency = useCurrencyLocale()
  // Currency is locked on edit, so resolve its market locale once. The amount
  // hydrates from the canonical API value (`"50.00"`) but is displayed/edited
  // in that locale's format (`"50,00"` for EUR); on submit we normalize back to
  // canonical. Displaying in the same locale we normalize from keeps an
  // untouched amount from being mangled on save.
  const creditLocale = localeForCurrency(credit.currency) || 'en'
  const { decimal, symbol } = currencyParts(credit.currency, creditLocale)

  const form = useForm<EditStoreCreditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(editStoreCreditFormSchema) as any,
    defaultValues: {
      amount: credit.amount ? credit.amount.replace('.', decimal) : '',
      memo: credit.memo ?? '',
    },
  })
  const { errors } = form.formState

  const mutation = useUpdateCustomerStoreCredit(customerId, credit.id)

  async function onSubmit(values: EditStoreCreditFormValues) {
    const params: StoreCreditUpdateParams = {}

    if (!amountLocked) {
      const amountValue = values.amount.toString().trim()
      // Normalize from the credit's display locale to the canonical
      // `"1234.56"` the API expects.
      if (amountValue) {
        params.amount = normalizeMoneyInput(amountValue, creditLocale)
      }
    }

    params.memo = values.memo

    try {
      await mutation.mutateAsync(params)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.customers.detail.edit_credit')}</DialogTitle>
          <DialogDescription>
            {t('admin.customers.detail.store_credit.edit_description')}
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
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="edit-sc-amount">
                    {t('admin.fields.store_credit.amount.label')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupAddon>
                      <InputGroupText>{symbol}</InputGroupText>
                    </InputGroupAddon>
                    <InputGroupInput
                      id="edit-sc-amount"
                      type="text"
                      inputMode="decimal"
                      disabled={amountLocked}
                      aria-invalid={!!errors.amount || undefined}
                      {...form.register('amount')}
                    />
                  </InputGroup>
                  <FieldError errors={[errors.amount]} />
                </Field>
                <Field>
                  {/* Currency is locked: the API doesn't accept `currency`
                      on update (changing it on a partially-used credit
                      would invalidate amount_used / amount_remaining). We
                      surface it disabled so the merchant always sees which
                      currency the credit is in. */}
                  <FieldLabel htmlFor="edit-sc-currency">
                    {t('admin.fields.store_credit.currency.label')}
                  </FieldLabel>
                  <CurrencySelect id="edit-sc-currency" value={credit.currency} disabled />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="edit-sc-memo">
                  {t('admin.fields.store_credit.memo.label')}
                </FieldLabel>
                <Textarea
                  id="edit-sc-memo"
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
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
