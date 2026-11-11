import type { Seller } from '@spree/admin-sdk'
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
  Input,
} from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerValuesToParams } from '../../../schemas/seller'
import { ReadRow } from '../read-row'
import { SellerAddress } from './seller-address-card'
import { SellerInlineForm } from './seller-inline-form'

/**
 * How the marketplace reaches the seller: their emails, then the addresses an
 * invoice and a customer return are sent to. The pencil edits the emails in
 * place; each address has its own.
 */
export function SellerContactCard({ seller, canEdit }: { seller: Seller; canEdit: boolean }) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState(false)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.contact')}</CardTitle>
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
      <CardContent className="flex flex-col gap-4">
        {editing ? (
          <SellerInlineForm
            seller={seller}
            label={t('admin.sellers.detail.edit_contact')}
            toParams={(values) => {
              const params = sellerValuesToParams(values)
              return { contact_email: params.contact_email, billing_email: params.billing_email }
            }}
            onDone={() => setEditing(false)}
          >
            {(form) => {
              const { errors } = form.formState
              return (
                <>
                  <Field>
                    <FieldLabel htmlFor="seller-contact-email">
                      {t('admin.fields.contact_email.label')}
                    </FieldLabel>
                    <Input
                      id="seller-contact-email"
                      type="email"
                      aria-invalid={!!errors.contact_email || undefined}
                      {...form.register('contact_email')}
                    />
                    <FieldDescription>
                      {t('admin.fields.seller.contact_email.help')}
                    </FieldDescription>
                    <FieldError errors={[errors.contact_email]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="seller-billing-email">
                      {t('admin.fields.seller.billing_email.label')}
                    </FieldLabel>
                    <Input
                      id="seller-billing-email"
                      type="email"
                      aria-invalid={!!errors.billing_email || undefined}
                      {...form.register('billing_email')}
                    />
                    <FieldDescription>
                      {t('admin.fields.seller.billing_email.help')}
                    </FieldDescription>
                    <FieldError errors={[errors.billing_email]} />
                  </Field>
                </>
              )
            }}
          </SellerInlineForm>
        ) : (
          <div className="flex flex-col gap-3">
            <ReadRow label={t('admin.fields.contact_email.label')}>
              {seller.contact_email ? (
                <a href={`mailto:${seller.contact_email}`}>{seller.contact_email}</a>
              ) : null}
            </ReadRow>
            <ReadRow label={t('admin.fields.seller.billing_email.label')}>
              {seller.billing_email ? (
                <a href={`mailto:${seller.billing_email}`}>{seller.billing_email}</a>
              ) : null}
            </ReadRow>
          </div>
        )}
        <div className="border-border-subtle border-t pt-4">
          <SellerAddress seller={seller} addressKey="billing_address" canEdit={canEdit} />
        </div>
        <div className="border-border-subtle border-t pt-4">
          <SellerAddress seller={seller} addressKey="returns_address" canEdit={canEdit} />
        </div>
      </CardContent>
    </Card>
  )
}
