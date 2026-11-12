import type { Seller } from '@spree/admin-sdk'
import { ReadRow, StoreDatePicker } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldDescription,
  FieldLabel,
  RelativeTime,
} from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useUpdateSeller } from '../../../hooks/use-sellers'
import { sellerValuesToParams } from '../../../schemas/seller'
import { SellerInlineForm } from './seller-inline-form'

/**
 * Whether the seller is away. Their catalog stays visible while they are, but
 * nothing can be bought from them until the date passes or it is ended here.
 */
export function SellerHolidayCard({ seller, canEdit }: { seller: Seller; canEdit: boolean }) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState(false)
  const updateMutation = useUpdateSeller(seller.id)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.holiday.title')}</CardTitle>
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
          <SellerInlineForm
            seller={seller}
            label={t('admin.sellers.holiday.title')}
            toParams={(values) => ({
              holiday_mode_until: sellerValuesToParams(values).holiday_mode_until,
            })}
            onDone={() => setEditing(false)}
          >
            {(form) => (
              <Field>
                <FieldLabel htmlFor="seller-holiday-mode-until">
                  {t('admin.fields.seller.holiday_mode_until.label')}
                </FieldLabel>
                <Controller
                  name="holiday_mode_until"
                  control={form.control}
                  render={({ field }) => (
                    <StoreDatePicker
                      id="seller-holiday-mode-until"
                      value={field.value || null}
                      onChange={(next) => field.onChange(next ?? '')}
                      placeholder={t('admin.fields.seller.holiday_mode_until.placeholder')}
                      includeTime
                    />
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.seller.holiday_mode_until.help')}
                </FieldDescription>
              </Field>
            )}
          </SellerInlineForm>
        ) : seller.on_holiday && seller.holiday_mode_until ? (
          <>
            <ReadRow label={t('admin.fields.seller.holiday_mode_until.label')}>
              <RelativeTime iso={seller.holiday_mode_until} />
            </ReadRow>
            <p className="text-muted-foreground text-base">
              {t('admin.sellers.on_holiday_notice')}
            </p>
            {canEdit && (
              <Button
                variant="outline"
                size="sm"
                className="self-start"
                disabled={updateMutation.isPending}
                onClick={() => updateMutation.mutate({ holiday_mode_until: null })}
              >
                {t('admin.sellers.holiday.end')}
              </Button>
            )}
          </>
        ) : (
          <p className="text-muted-foreground text-base">{t('admin.sellers.holiday.off')}</p>
        )}
      </CardContent>
    </Card>
  )
}
