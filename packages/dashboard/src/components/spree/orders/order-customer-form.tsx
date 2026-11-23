import type { Order } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  useConfirm,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'
import { CustomerCombobox } from '../customers/customer-combobox'

/**
 * Who the order belongs to: an existing customer, or a guest known only by
 * email. Clearing the customer turns the order into a guest one. Edited in
 * place in the customer card, so adding a new customer opens the only sheet.
 */
export function OrderCustomerForm({ order, onDone }: { order: Order; onDone: () => void }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
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
    // A placed order leaves the customer's order history and account with
    // its customer, so detaching one is confirmed first.
    const detachingFromPlacedOrder = !customerId && !!order.customer_id && !!order.completed_at
    if (
      detachingFromPlacedOrder &&
      !(await confirm({
        message: t('admin.orders.detail.customer_edit.confirm_detach'),
        variant: 'destructive',
        confirmLabel: t('admin.orders.detail.customer_edit.detach'),
      }))
    ) {
      return
    }

    try {
      await mutation.mutateAsync(
        customerId
          ? { customer_id: customerId, ...(customerEmail && { email: customerEmail }) }
          : { customer_id: null, email: values.email },
      )
      onDone()
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) throw error
    }
  }

  return (
    <form
      onSubmit={form.handleSubmit(onSubmit)}
      aria-label={t('admin.orders.detail.customer_edit.title')}
      className="flex flex-col gap-3"
    >
      <FieldGroup className="gap-3">
        {form.formState.errors.root?.message && (
          <p className="text-base text-destructive">{form.formState.errors.root.message}</p>
        )}
        <Field>
          <FieldLabel htmlFor="order-customer-picker">
            {t('admin.pages.orders.new.select_customer')}
          </FieldLabel>
          <CustomerCombobox
            queryKey="order-customer-picker"
            companyId={order.company_id}
            id="order-customer-picker"
            value={customerId}
            onChange={(id, customer) => {
              setCustomerId(id ?? undefined)
              setCustomerEmail(customer?.email ?? undefined)
            }}
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
      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" size="sm" onClick={onDone}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="submit" size="sm" disabled={mutation.isPending}>
          {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
        </Button>
      </div>
    </form>
  )
}
