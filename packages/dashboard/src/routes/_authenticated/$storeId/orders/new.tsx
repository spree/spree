import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer, Variant } from '@spree/admin-sdk'
import {
  adminClient,
  formatPrice,
  mapSpreeErrorsToForm,
  PageHeader,
  ResourceCombobox,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  ResourceLayout,
  Switch,
  Textarea,
} from '@spree/dashboard-ui'
import { useMutation, useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { TrashIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { customerAutocompleteProps } from '@/hooks/use-customers'
import { NEW_ORDER_DEFAULTS, type NewOrderFormValues, newOrderFormSchema } from '@/schemas/order'

export const Route = createFileRoute('/_authenticated/$storeId/orders/new')({
  component: NewOrderPage,
})

interface PendingItem {
  variant: Variant
  quantity: number
}

function NewOrderPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()

  // Customer/items/typeahead state lives outside RHF — they're domain objects
  // (Customer record, picked Variants) and bespoke widgets (ResourceCombobox,
  // typeahead button list, items table), not standard form fields.
  const [customer, setCustomer] = useState<Customer | null>(null)
  const [items, setItems] = useState<PendingItem[]>([])
  const [variantSearch, setVariantSearch] = useState('')
  const [useDefaultAddress, setUseDefaultAddress] = useState(true)

  const form = useForm<NewOrderFormValues>({
    resolver: zodResolver(newOrderFormSchema),
    defaultValues: NEW_ORDER_DEFAULTS,
  })
  const { errors } = form.formState

  // Variant typeahead
  const { data: variantsData } = useQuery({
    queryKey: ['variants', 'search', variantSearch],
    queryFn: () => adminClient.variants.list({ search: variantSearch, limit: 8 }),
    enabled: variantSearch.length >= 3,
    staleTime: 30_000,
  })
  const variantResults = variantsData?.data ?? []

  const createMutation = useMutation({
    mutationFn: (values: NewOrderFormValues) => {
      const payload: Record<string, unknown> = {
        items: items.map((i) => ({ variant_id: i.variant.id, quantity: i.quantity })),
      }
      if (customer) {
        payload.customer_id = customer.id
        payload.use_customer_default_address = useDefaultAddress
      } else if (values.email) {
        payload.email = values.email
      }
      if (values.internal_note) payload.internal_note = values.internal_note
      if (values.customer_note) payload.customer_note = values.customer_note
      if (values.coupon_code) payload.coupon_code = values.coupon_code
      return adminClient.orders.create(payload)
    },
    onSuccess: (order) => {
      navigate({ to: '/$storeId/orders/$orderId', params: { storeId, orderId: order.id } })
    },
  })

  const email = form.watch('email')
  const canSubmit =
    (Boolean(customer) || email.length > 0) && items.length > 0 && !createMutation.isPending

  async function onSubmit(values: NewOrderFormValues) {
    if (!canSubmit) return
    try {
      await createMutation.mutateAsync(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  function addItem(variant: Variant) {
    const existing = items.find((i) => i.variant.id === variant.id)
    if (existing) {
      setItems(
        items.map((i) => (i.variant.id === variant.id ? { ...i, quantity: i.quantity + 1 } : i)),
      )
    } else {
      setItems([...items, { variant, quantity: 1 }])
    }
    setVariantSearch('')
  }

  function updateQuantity(variantId: string, quantity: number) {
    if (quantity < 1) return
    setItems(items.map((i) => (i.variant.id === variantId ? { ...i, quantity } : i)))
  }

  function removeItem(variantId: string) {
    setItems(items.filter((i) => i.variant.id !== variantId))
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={<PageHeader title={t('admin.pages.orders.new.title')} backTo="orders/drafts" />}
        main={
          <>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.orders.new.section_customer')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel>{t('admin.pages.orders.new.select_customer')}</FieldLabel>
                    <ResourceCombobox<Customer>
                      {...customerAutocompleteProps('customer-picker')}
                      value={customer?.id}
                      onChange={(_id, record) => setCustomer(record)}
                      renderOption={(c) => (
                        <div>
                          <div className="font-medium">{c.email}</div>
                          {(c.first_name || c.last_name) && (
                            <div className="text-xs text-muted-foreground">{c.full_name}</div>
                          )}
                        </div>
                      )}
                    />
                  </Field>
                  {!customer && (
                    <Field>
                      <FieldLabel htmlFor="order-email">
                        {t('admin.fields.order.email.label')}
                      </FieldLabel>
                      <Input
                        id="order-email"
                        type="email"
                        placeholder={t('admin.fields.order.email.placeholder')}
                        aria-invalid={!!errors.email || undefined}
                        {...form.register('email')}
                      />
                      <FieldError errors={[errors.email]} />
                    </Field>
                  )}
                </FieldGroup>

                {customer && (
                  <div className="mt-4 flex items-center gap-3">
                    <Switch checked={useDefaultAddress} onCheckedChange={setUseDefaultAddress} />
                    <span className="text-sm">{t('admin.orders.new.use_default_addresses')}</span>
                  </div>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.orders.new.section_items')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel>{t('admin.orders.new.add_variant')}</FieldLabel>
                    <Input
                      placeholder={t('admin.pages.orders.new.search_variant')}
                      value={variantSearch}
                      onChange={(e) => setVariantSearch(e.target.value)}
                    />
                    {variantSearch.length >= 3 && variantResults.length > 0 && (
                      <div className="mt-1 rounded-lg border border-border bg-popover text-popover-foreground shadow-xs max-h-[280px] overflow-y-auto">
                        {variantResults.map((v) => (
                          <button
                            key={v.id}
                            type="button"
                            onClick={() => addItem(v)}
                            className="block w-full px-3 py-2.5 text-left text-sm hover:bg-muted transition-colors border-b last:border-0"
                          >
                            <div className="font-medium">{v.product_name ?? v.sku ?? v.id}</div>
                            <div className="text-xs text-muted-foreground">
                              SKU {v.sku} · {formatPrice(v.price)}
                            </div>
                          </button>
                        ))}
                      </div>
                    )}
                  </Field>
                </FieldGroup>

                {items.length > 0 && (
                  <div className="mt-4 overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b bg-muted/50 text-muted-foreground">
                          <th className="p-3 pl-5 text-left font-normal">
                            {t('admin.orders.new.items_table.variant')}
                          </th>
                          <th className="p-3 text-left font-normal">
                            {t('admin.orders.new.items_table.sku')}
                          </th>
                          <th className="p-3 text-right font-normal">
                            {t('admin.orders.new.items_table.qty')}
                          </th>
                          <th className="p-3 pr-5 w-10" />
                        </tr>
                      </thead>
                      <tbody>
                        {items.map(({ variant, quantity }) => (
                          <tr key={variant.id} className="border-b last:border-b-0">
                            <td className="p-3 pl-5 font-medium">
                              {variant.product_name ?? variant.sku ?? variant.id}
                            </td>
                            <td className="p-3 text-muted-foreground">{variant.sku}</td>
                            <td className="p-3 text-right">
                              <Input
                                type="number"
                                min={1}
                                value={quantity}
                                onChange={(e) => updateQuantity(variant.id, Number(e.target.value))}
                                className="w-20 text-right ml-auto"
                              />
                            </td>
                            <td className="p-3 pr-5 text-right">
                              <Button
                                type="button"
                                size="icon-xs"
                                variant="ghost"
                                onClick={() => removeItem(variant.id)}
                              >
                                <TrashIcon className="size-4" />
                              </Button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </CardContent>
            </Card>
          </>
        }
        sidebar={
          <>
            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.orders.new.section_notes')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="customer-note">
                      {t('admin.fields.order.customer_note.label')}
                    </FieldLabel>
                    <Textarea
                      id="customer-note"
                      rows={3}
                      aria-invalid={!!errors.customer_note || undefined}
                      {...form.register('customer_note')}
                    />
                    <FieldError errors={[errors.customer_note]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="internal-note">
                      {t('admin.fields.order.internal_note.label')}
                    </FieldLabel>
                    <Textarea
                      id="internal-note"
                      rows={3}
                      aria-invalid={!!errors.internal_note || undefined}
                      {...form.register('internal_note')}
                    />
                    <FieldError errors={[errors.internal_note]} />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>{t('admin.orders.new.section_discount')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="coupon-code">
                      {t('admin.fields.order.coupon_code.label')}
                    </FieldLabel>
                    <Input
                      id="coupon-code"
                      placeholder={t('admin.fields.order.coupon_code.placeholder')}
                      aria-invalid={!!errors.coupon_code || undefined}
                      {...form.register('coupon_code')}
                    />
                    <FieldError errors={[errors.coupon_code]} />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="flex flex-col gap-3 pt-6">
                <Button type="submit" disabled={!canSubmit}>
                  {createMutation.isPending
                    ? t('admin.actions.creating')
                    : t('admin.pages.orders.new.title')}
                </Button>
                {createMutation.error && !errors.root && (
                  <p className="text-sm text-destructive">
                    {(createMutation.error as Error).message}
                  </p>
                )}
                <p className="text-xs text-muted-foreground">
                  {t('admin.orders.new.creates_draft_note')}
                </p>
              </CardContent>
            </Card>
          </>
        }
      />
    </form>
  )
}
