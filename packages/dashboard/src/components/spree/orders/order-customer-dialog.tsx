import type { Customer, Order } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, ResourceCombobox } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { customerAutocompleteProps } from '../../../hooks/use-customers'
import { useOrderMutation } from '../../../hooks/use-order'

/**
 * Who the order belongs to: an existing customer, or a guest known only by
 * email. Clearing the customer turns the order into a guest one.
 */
export function OrderCustomerDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const [customerId, setCustomerId] = useState<string | undefined>(order.customer_id ?? undefined)
  // The order's email is only taken from the customer when the order is
  // created, so a newly picked customer's email is sent alongside it —
  // otherwise notifications keep going to the previous customer.
  const [customerEmail, setCustomerEmail] = useState<string | undefined>()
  const form = useForm<{ email: string }>({ defaultValues: { email: order.email ?? '' } })

  const mutation = useOrderMutation(
    order.id,
    (params: { customer_id: string | null; email?: string }) =>
      adminClient.orders.update(order.id, params),
  )

  async function onSubmit(values: { email: string }) {
    try {
      await mutation.mutateAsync(
        customerId
          ? { customer_id: customerId, ...(customerEmail && { email: customerEmail }) }
          : { customer_id: null, email: values.email },
      )
      onOpenChange(false)
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) throw error
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogHeader>
            <DialogTitle>{t('admin.orders.detail.customer_edit.title')}</DialogTitle>
          </DialogHeader>
          <DialogBody>
            <FieldGroup>
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive">{form.formState.errors.root.message}</p>
              )}
              <Field>
                <FieldLabel htmlFor="order-customer-picker">
                  {t('admin.pages.orders.new.select_customer')}
                </FieldLabel>
                <ResourceCombobox<Customer>
                  {...customerAutocompleteProps('order-customer-picker', order.company_id)}
                  id="order-customer-picker"
                  value={customerId}
                  onChange={(id, customer) => {
                    setCustomerId(id)
                    setCustomerEmail(customer?.email ?? undefined)
                  }}
                  renderOption={(customer) => (
                    <div>
                      <div className="font-medium">{customer.email}</div>
                      {(customer.first_name || customer.last_name) && (
                        <div className="text-xs text-muted-foreground">{customer.full_name}</div>
                      )}
                    </div>
                  )}
                />
                <FieldDescription>
                  {t('admin.orders.detail.customer_edit.customer_help')}
                </FieldDescription>
              </Field>
              {!customerId && (
                <Field>
                  <FieldLabel htmlFor="order-customer-email">
                    {t('admin.fields.order.email.label')}
                  </FieldLabel>
                  <Input
                    id="order-customer-email"
                    type="email"
                    placeholder={t('admin.fields.order.email.placeholder')}
                    aria-invalid={!!form.formState.errors.email || undefined}
                    {...form.register('email', { required: true })}
                  />
                  <FieldError errors={[form.formState.errors.email]} />
                </Field>
              )}
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
