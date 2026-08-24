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
  RichTextEditor,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useOnSheetOpen } from '../../../hooks/use-on-sheet-open'
import { useUpdateSeller } from '../../../hooks/use-sellers'
import {
  SELLER_DEFAULTS,
  type SellerFormValues,
  sellerFormSchema,
  sellerImageParams,
  sellerValuesToParams,
} from '../../../schemas/seller'
import { ResourceImageField } from '../resource-image-field'

/** The profile the seller also maintains from their own panel. */
export function SellerEditProfileSheet({
  seller,
  open,
  onOpenChange,
}: {
  seller: Seller
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateSeller(seller.id)

  const form = useForm<SellerFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(sellerFormSchema) as any,
    defaultValues: SELLER_DEFAULTS,
  })

  // Re-seed from the latest record each time the sheet opens.
  //
  // Images reset to the empty triple: the persisted ones are passed to the
  // field as `serverUrl`, and the triple only carries what the operator
  // changes this time round.
  useOnSheetOpen(open, () => {
    form.reset({
      ...SELLER_DEFAULTS,
      name: seller.name,
      slug: seller.slug,
      contact_email: seller.contact_email ?? '',
      billing_email: seller.billing_email ?? '',
      about: seller.about_html ?? '',
    })
  })

  async function onSubmit(values: SellerFormValues) {
    try {
      // Only this sheet's own fields — the settlement sheet owns the rest, and
      // sending them here would post this form's untouched defaults over them.
      const params = sellerValuesToParams(values)
      await updateMutation.mutateAsync({
        ...sellerImageParams(values),
        name: params.name,
        slug: params.slug,
        contact_email: params.contact_email,
        billing_email: params.billing_email,
        about: params.about,
      })
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
          <SheetTitle>{t('admin.sellers.detail.edit_profile')}</SheetTitle>
          <SheetDescription>{t('admin.sellers.detail.edit_profile_description')}</SheetDescription>
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
              <ResourceImageField
                form={form}
                kind="logo"
                serverUrl={seller.logo_url}
                square
                translationNamespace="admin.sellers"
                labelKey="logo_label"
                helpKey="logo_help"
              />
              <ResourceImageField
                form={form}
                kind="square_logo"
                serverUrl={seller.square_logo_url}
                square
                translationNamespace="admin.sellers"
                labelKey="square_logo_label"
                helpKey="square_logo_help"
              />
              <ResourceImageField
                form={form}
                kind="cover_photo"
                serverUrl={seller.cover_photo_url}
                translationNamespace="admin.sellers"
                labelKey="cover_photo_label"
                helpKey="cover_photo_help"
              />

              <Field>
                <FieldLabel htmlFor="seller-name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="seller-name"
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="seller-slug">{t('admin.fields.slug.label')}</FieldLabel>
                <Input
                  id="seller-slug"
                  aria-invalid={!!errors.slug || undefined}
                  {...form.register('slug')}
                />
                <FieldDescription>{t('admin.fields.seller.slug.help')}</FieldDescription>
                <FieldError errors={[errors.slug]} />
              </Field>

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
                <FieldDescription>{t('admin.fields.seller.contact_email.help')}</FieldDescription>
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
                <FieldDescription>{t('admin.fields.seller.billing_email.help')}</FieldDescription>
                <FieldError errors={[errors.billing_email]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="seller-about">
                  {t('admin.fields.seller.about.label')}
                </FieldLabel>
                <Controller
                  control={form.control}
                  name="about"
                  render={({ field }) => (
                    <RichTextEditor
                      id="seller-about"
                      ariaLabel={t('admin.fields.seller.about.label')}
                      value={field.value ?? ''}
                      onChange={field.onChange}
                    />
                  )}
                />
                <FieldDescription>{t('admin.fields.seller.about.help')}</FieldDescription>
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
