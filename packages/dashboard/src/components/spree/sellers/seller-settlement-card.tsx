import type { Seller } from '@spree/admin-sdk'
import { PAYOUT_SCHEDULE_INTERVALS, TAX_REMITTANCES } from '@spree/core'
import {
  currencyParts,
  formatAmount,
  ReadRow,
  useMoneyLocale,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldDescription,
  FieldError,
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
} from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { useState } from 'react'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerValuesToParams } from '../../../schemas/seller'
import { SellerInlineForm } from './seller-inline-form'

/**
 * Operator-only: how and when this seller gets paid, and who remits tax. The
 * seller never sees or edits these.
 */
export function SellerSettlementCard({ seller, canEdit }: { seller: Seller; canEdit: boolean }) {
  const { t } = useTranslation()
  const { defaultCurrency } = useStore()
  const moneyLocale = useMoneyLocale()
  const [editing, setEditing] = useState(false)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.settlement')}</CardTitle>
        {canEdit && (
          <CardAction>
            <Button
              variant="ghost"
              size="icon-sm"
              // Opens only: leaving goes through Cancel, which asks before
              // discarding a change.
              disabled={editing}
              onClick={() => setEditing(true)}
              aria-label={t('admin.actions.edit')}
              aria-expanded={editing}
            >
              <PencilIcon className="size-4" />
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {editing ? (
          <SettlementForm
            seller={seller}
            currencySymbol={currencyParts(defaultCurrency, i18n.language).symbol}
            onDone={() => setEditing(false)}
          />
        ) : (
          <>
            <ReadRow label={t('admin.fields.seller.tax_remittance.label')}>
              {t(`admin.sellers.tax_remittance.${seller.tax_remittance}`, {
                defaultValue: seller.tax_remittance,
              })}
            </ReadRow>
            <ReadRow label={t('admin.fields.seller.payouts_schedule_interval.label')}>
              {seller.payouts_schedule_interval
                ? t(`admin.sellers.payout_interval.${seller.payouts_schedule_interval}`)
                : t('admin.sellers.payout_interval.inherit')}
            </ReadRow>
            <ReadRow label={t('admin.fields.seller.minimum_payout_amount.label')}>
              {seller.minimum_payout_amount
                ? formatAmount(seller.minimum_payout_amount, defaultCurrency, moneyLocale)
                : null}
            </ReadRow>
          </>
        )}
      </CardContent>
    </Card>
  )
}

function SettlementForm({
  seller,
  currencySymbol,
  onDone,
}: {
  seller: Seller
  currencySymbol: string
  onDone: () => void
}) {
  const { t } = useTranslation()

  const remittanceOptions = TAX_REMITTANCES.map((value) => ({
    value,
    label: t(`admin.sellers.tax_remittance.${value}`),
  }))
  const intervalOptions = [
    { value: '', label: t('admin.sellers.payout_interval.inherit') },
    ...PAYOUT_SCHEDULE_INTERVALS.map((value) => ({
      value,
      label: t(`admin.sellers.payout_interval.${value}`),
    })),
  ]

  return (
    <SellerInlineForm
      seller={seller}
      label={t('admin.sellers.detail.edit_settlement')}
      toParams={(values) => {
        const params = sellerValuesToParams(values)
        return {
          tax_remittance: params.tax_remittance,
          payouts_schedule_interval: params.payouts_schedule_interval,
          minimum_payout_amount: params.minimum_payout_amount,
        }
      }}
      onDone={onDone}
    >
      {(form) => (
        <>
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
                step="any"
                min="0"
                inputMode="decimal"
                aria-invalid={!!form.formState.errors.minimum_payout_amount || undefined}
                {...form.register('minimum_payout_amount')}
              />
            </InputGroup>
            <FieldDescription>
              {t('admin.fields.seller.minimum_payout_amount.help')}
            </FieldDescription>
            <FieldError errors={[form.formState.errors.minimum_payout_amount]} />
          </Field>
        </>
      )}
    </SellerInlineForm>
  )
}
