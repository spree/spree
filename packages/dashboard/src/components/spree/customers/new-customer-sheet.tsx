import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, TagCombobox } from '@spree/dashboard-core'
import {
  Button,
  Field,
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
  Switch,
} from '@spree/dashboard-ui'
import { useMutation } from '@tanstack/react-query'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  NEW_CUSTOMER_DEFAULTS,
  type NewCustomerFormValues,
  newCustomerFormSchema,
} from '../../../schemas/customer'

/**
 * Creates a customer from email, name, phone, tags, marketing consent and an
 * internal note. Shared by the customers page, which then opens the new
 * customer, and by customer pickers, which select them.
 */
export function NewCustomerSheet({
  open,
  onOpenChange,
  onCreated,
  defaultEmail,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  onCreated: (customer: Customer) => void
  /** Prefills the email, e.g. with what was typed into a picker. */
  defaultEmail?: string
}) {
  const { t } = useTranslation()

  const form = useForm<NewCustomerFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(newCustomerFormSchema) as any,
    defaultValues: { ...NEW_CUSTOMER_DEFAULTS, email: defaultEmail ?? '' },
  })

  const createMutation = useMutation({
    mutationFn: (params: Parameters<typeof adminClient.customers.create>[0]) =>
      adminClient.customers.create(params),
    onSuccess: (customer) => onCreated(customer),
  })

  async function onSubmit(values: NewCustomerFormValues) {
    const payload: Parameters<typeof adminClient.customers.create>[0] = {
      email: values.email.trim(),
      accepts_email_marketing: values.accepts_email_marketing,
    }
    if (values.first_name.trim()) payload.first_name = values.first_name.trim()
    if (values.last_name.trim()) payload.last_name = values.last_name.trim()
    if (values.phone.trim()) payload.phone = values.phone.trim()
    // The editor emits an empty paragraph once it has been focused and cleared,
    // which is not a note.
    const internalNote = values.internal_note.trim()
    if (internalNote && internalNote !== '<p></p>') payload.internal_note = internalNote
    if (values.tags.length) payload.tags = values.tags

    try {
      await createMutation.mutateAsync(payload)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.customers.new_cta')}</SheetTitle>
          <SheetDescription>{t('admin.customers.new_sheet_description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            // Opened from a dialog's form, this sheet shares its React tree, so
            // its submit would also reach that form without this.
            event.stopPropagation()
            void form.handleSubmit(onSubmit)(event)
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="email">{t('admin.fields.email.label')}</FieldLabel>
                <Input
                  id="email"
                  type="email"
                  autoFocus
                  aria-invalid={!!form.formState.errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldError errors={[form.formState.errors.email]} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="first_name">{t('admin.fields.first_name.label')}</FieldLabel>
                  <Input
                    id="first_name"
                    aria-invalid={!!form.formState.errors.first_name || undefined}
                    {...form.register('first_name')}
                  />
                  <FieldError errors={[form.formState.errors.first_name]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="last_name">{t('admin.fields.last_name.label')}</FieldLabel>
                  <Input
                    id="last_name"
                    aria-invalid={!!form.formState.errors.last_name || undefined}
                    {...form.register('last_name')}
                  />
                  <FieldError errors={[form.formState.errors.last_name]} />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="phone">{t('admin.fields.phone.label')}</FieldLabel>
                <Input
                  id="phone"
                  aria-invalid={!!form.formState.errors.phone || undefined}
                  {...form.register('phone')}
                />
                <FieldError errors={[form.formState.errors.phone]} />
              </Field>
              <Field>
                <FieldLabel>{t('admin.fields.customer.tags.label')}</FieldLabel>
                <Controller
                  name="tags"
                  control={form.control}
                  render={({ field }) => (
                    <TagCombobox
                      taggableType="customer"
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
              </Field>
              <Field>
                <div className="flex items-start justify-between gap-4">
                  <FieldLabel htmlFor="accepts_email_marketing" className="cursor-pointer">
                    {t('admin.fields.customer.accepts_email_marketing.label')}
                  </FieldLabel>
                  <Controller
                    name="accepts_email_marketing"
                    control={form.control}
                    render={({ field }) => (
                      <Switch
                        id="accepts_email_marketing"
                        checked={!!field.value}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </div>
              </Field>
              <Field>
                <FieldLabel htmlFor="internal_note">
                  {t('admin.fields.customer.internal_note.label')}
                </FieldLabel>
                <Controller
                  control={form.control}
                  name="internal_note"
                  render={({ field }) => (
                    <RichTextEditor
                      id="internal_note"
                      ariaLabel={t('admin.fields.customer.internal_note.label')}
                      placeholder={t('admin.fields.customer.internal_note.placeholder')}
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
                <FieldError errors={[form.formState.errors.internal_note]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={createMutation.isPending}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending
                ? t('admin.actions.creating')
                : t('admin.pages.customers.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
