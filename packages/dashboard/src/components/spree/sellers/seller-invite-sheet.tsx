import { zodResolver } from '@hookform/resolvers/zod'
import type { Seller } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useInviteSeller } from '../../../hooks/use-sellers'
import { type SellerInviteValues, sellerInviteSchema } from '../../../schemas/seller'

export function SellerInviteSheet({
  seller,
  open,
  onOpenChange,
}: {
  seller: Seller
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const inviteMutation = useInviteSeller(seller.id)
  const form = useForm<SellerInviteValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(sellerInviteSchema) as any,
    defaultValues: { email: seller.contact_email ?? '' },
  })

  async function onSubmit(values: SellerInviteValues) {
    try {
      await inviteMutation.mutateAsync(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.sellers.invite_sheet.title')}</SheetTitle>
          <SheetDescription>{t('admin.sellers.invite_sheet.description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            // This sheet renders inside the detail page's own tree; without
            // stopping the bubble the browser would submit an outer form.
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
                <FieldLabel htmlFor="invite-email">{t('admin.fields.email.label')}</FieldLabel>
                <Input
                  id="invite-email"
                  type="email"
                  autoFocus
                  aria-invalid={!!errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldDescription>{t('admin.sellers.invite_sheet.email_help')}</FieldDescription>
                <FieldError errors={[errors.email]} />
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
              {form.formState.isSubmitting
                ? t('admin.actions.saving')
                : t('admin.sellers.actions.send_invitation')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
