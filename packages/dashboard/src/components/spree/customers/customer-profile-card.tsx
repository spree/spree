import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, Subject, TagCombobox } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RelativeTime,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { MailIcon, PencilIcon, PhoneIcon, StarIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useUpdateCustomer } from '../../../hooks/use-customers'
import {
  type CustomerProfileFormValues,
  customerProfileFormSchema,
} from '../../../schemas/customer'

export function CustomerProfileCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [editOpen, setEditOpen] = useState(false)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.customers.detail.section_profile')}</CardTitle>
          <CardAction>
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => setEditOpen(true)}
              aria-label={t('admin.actions.edit')}
            >
              <PencilIcon className="size-4" />
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <div className="flex items-center gap-2 text-sm">
            <MailIcon className="size-4 text-muted-foreground" />
            <span>{customer.email}</span>
          </div>
          {customer.phone && (
            <div className="flex items-center gap-2 text-sm">
              <PhoneIcon className="size-4 text-muted-foreground" />
              <span>{customer.phone}</span>
            </div>
          )}
          <div className="flex items-center gap-2 text-sm">
            <StarIcon className="size-4 text-muted-foreground" />
            <span>
              {customer.accepts_email_marketing
                ? t('admin.customers.detail.subscribed_to_marketing')
                : t('admin.customers.detail.not_subscribed_to_marketing')}
            </span>
          </div>
          {customer.created_at && (
            <div className="text-xs text-muted-foreground">
              <RelativeTime
                iso={customer.created_at}
                prefix={t('admin.customers.detail.customer_since')}
              />
            </div>
          )}
        </CardContent>
      </Card>
      <EditProfileSheet customer={customer} open={editOpen} onOpenChange={setEditOpen} />
    </>
  )
}

function EditProfileSheet({
  customer,
  open,
  onOpenChange,
}: {
  customer: Customer
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const form = useForm<CustomerProfileFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customerProfileFormSchema) as any,
    defaultValues: {
      email: customer.email,
      first_name: customer.first_name ?? '',
      last_name: customer.last_name ?? '',
      phone: customer.phone ?? '',
      tags: customer.tags ?? [],
      accepts_email_marketing: customer.accepts_email_marketing,
    },
  })
  const { errors } = form.formState
  const mutation = useUpdateCustomer(customer.id)

  // Sheet stays mounted across opens; re-seed form with the latest server
  // values whenever the dialog re-opens or the underlying record refreshes,
  // so stale edits from a previous session are discarded.
  useEffect(() => {
    if (open) {
      form.reset({
        email: customer.email,
        first_name: customer.first_name ?? '',
        last_name: customer.last_name ?? '',
        phone: customer.phone ?? '',
        tags: customer.tags ?? [],
        accepts_email_marketing: customer.accepts_email_marketing,
      })
    }
  }, [open, customer, form])

  async function onSubmit(values: CustomerProfileFormValues) {
    try {
      await mutation.mutateAsync(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.customers.edit_sheet_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.customers.detail.edit_profile_description')}
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="email">{t('admin.fields.email.label')}</FieldLabel>
                <Input
                  id="email"
                  type="email"
                  aria-invalid={!!errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldError errors={[errors.email]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="first_name">{t('admin.fields.first_name.label')}</FieldLabel>
                <Input
                  id="first_name"
                  aria-invalid={!!errors.first_name || undefined}
                  {...form.register('first_name')}
                />
                <FieldError errors={[errors.first_name]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="last_name">{t('admin.fields.last_name.label')}</FieldLabel>
                <Input
                  id="last_name"
                  aria-invalid={!!errors.last_name || undefined}
                  {...form.register('last_name')}
                />
                <FieldError errors={[errors.last_name]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="phone">{t('admin.fields.phone.label')}</FieldLabel>
                <Input
                  id="phone"
                  aria-invalid={!!errors.phone || undefined}
                  {...form.register('phone')}
                />
                <FieldError errors={[errors.phone]} />
              </Field>
              <Field>
                <FieldLabel>{t('admin.fields.customer.tags.label')}</FieldLabel>
                <Controller
                  name="tags"
                  control={form.control}
                  render={({ field }) => (
                    <TagCombobox
                      taggableType={Subject.Customer}
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
                      <Checkbox
                        id="accepts_email_marketing"
                        checked={!!field.value}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </div>
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={mutation.isPending}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
