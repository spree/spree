import { zodResolver } from '@hookform/resolvers/zod'
import type { Seller } from '@spree/admin-sdk'
import {
  currencyParts,
  mapSpreeErrorsToForm,
  StoreDatePicker,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import i18n from 'i18next'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useOnSheetOpen } from '../../../hooks/use-on-sheet-open'
import { useUpdateSeller } from '../../../hooks/use-sellers'
import {
  PAYOUT_INTERVALS,
  SELLER_DEFAULTS,
  type SellerFormValues,
  sellerFormSchema,
  sellerValuesToParams,
  TAX_REMITTANCES,
} from '../../../schemas/seller'

export function SellerEditSettlementSheet({
  seller,
  open,
  onOpenChange,
}: {
  seller: Seller
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { defaultCurrency } = useStore()
  const { symbol: currencySymbol } = currencyParts(defaultCurrency, i18n.language)
  const updateMutation = useUpdateSeller(seller.id)

  const form = useForm<SellerFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(sellerFormSchema) as any,
    defaultValues: SELLER_DEFAULTS,
  })

  useOnSheetOpen(open, () => {
    form.reset({
      ...SELLER_DEFAULTS,
      // Carried so the schema's required `name` still validates; the submit
      // below sends only this sheet's own fields.
      name: seller.name,
      tax_remittance: (seller.tax_remittance ?? 'seller') as SellerFormValues['tax_remittance'],
      payouts_schedule_interval: (seller.payouts_schedule_interval ??
        '') as SellerFormValues['payouts_schedule_interval'],
      minimum_payout_amount: seller.minimum_payout_amount ?? '',
      holiday_mode_until: seller.holiday_mode_until ?? '',
    })
  })

  async function onSubmit(values: SellerFormValues) {
    try {
      const params = sellerValuesToParams(values)
      await updateMutation.mutateAsync({
        tax_remittance: params.tax_remittance,
        payouts_schedule_interval: params.payouts_schedule_interval,
        minimum_payout_amount: params.minimum_payout_amount,
        holiday_mode_until: params.holiday_mode_until,
      })
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  const remittanceOptions = TAX_REMITTANCES.map((value) => ({
    value,
    label: t(`admin.sellers.tax_remittance.${value}`),
  }))
  const intervalOptions = [
    { value: '', label: t('admin.sellers.payout_interval.inherit') },
    ...PAYOUT_INTERVALS.map((value) => ({
      value,
      label: t(`admin.sellers.payout_interval.${value}`),
    })),
  ]

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.sellers.detail.edit_settlement')}</SheetTitle>
          <SheetDescription>
            {t('admin.sellers.detail.edit_settlement_description')}
          </SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}

              <Field>
                <FieldLabel htmlFor="tax_remittance">
                  {t('admin.fields.seller.tax_remittance.label')}
                </FieldLabel>
                <Controller
                  name="tax_remittance"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      items={remittanceOptions}
                      value={field.value ?? 'seller'}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id="tax_remittance" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {remittanceOptions.map((option) => (
                          <SelectItem key={option.value} value={option.value}>
                            {option.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <FieldDescription>{t('admin.fields.seller.tax_remittance.help')}</FieldDescription>
              </Field>

              <Field>
                <FieldLabel htmlFor="payouts_schedule_interval">
                  {t('admin.fields.seller.payouts_schedule_interval.label')}
                </FieldLabel>
                <Controller
                  name="payouts_schedule_interval"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      items={intervalOptions}
                      value={field.value ?? ''}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id="payouts_schedule_interval" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {intervalOptions.map((option) => (
                          <SelectItem key={option.value || 'inherit'} value={option.value}>
                            {option.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.seller.payouts_schedule_interval.help')}
                </FieldDescription>
              </Field>

              <Field>
                <FieldLabel htmlFor="minimum_payout_amount">
                  {t('admin.fields.seller.minimum_payout_amount.label')}
                </FieldLabel>
                <InputGroup>
                  <InputGroupAddon>
                    <InputGroupText>{currencySymbol}</InputGroupText>
                  </InputGroupAddon>
                  <InputGroupInput
                    id="minimum_payout_amount"
                    type="number"
                    step="0.01"
                    min="0"
                    inputMode="decimal"
                    aria-invalid={!!errors.minimum_payout_amount || undefined}
                    {...form.register('minimum_payout_amount')}
                  />
                </InputGroup>
                <FieldDescription>
                  {t('admin.fields.seller.minimum_payout_amount.help')}
                </FieldDescription>
                <FieldError errors={[errors.minimum_payout_amount]} />
              </Field>

              <Field>
                <FieldLabel>{t('admin.fields.seller.holiday_mode_until.label')}</FieldLabel>
                <Controller
                  name="holiday_mode_until"
                  control={form.control}
                  render={({ field }) => (
                    <StoreDatePicker
                      value={field.value || null}
                      onChange={(next) => field.onChange(next ?? '')}
                      placeholder={t('admin.fields.seller.holiday_mode_until.placeholder')}
                      includeTime
                      inline
                    />
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.seller.holiday_mode_until.help')}
                </FieldDescription>
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
