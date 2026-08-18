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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Textarea,
} from '@spree/dashboard-ui'
import { useMutation } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { TrashIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { ChannelSelect } from '../../../../components/spree/channel-select'
import { useChannels } from '../../../../hooks/use-channels'
import { customerAutocompleteProps } from '../../../../hooks/use-customers'
import {
  NEW_ORDER_DEFAULTS,
  type NewOrderFormValues,
  newOrderFormSchema,
} from '../../../../schemas/order'

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
  const [useDefaultAddress, setUseDefaultAddress] = useState(true)
  // `onChange` hands back only the option id, so keep the records the search
  // returned to resolve it. A ref, not state: it's a lookup table, and writing
  // it must not re-render the form mid-search.
  const variantById = useRef(new Map<string, Variant>())

  const form = useForm<NewOrderFormValues>({
    resolver: zodResolver(newOrderFormSchema),
    defaultValues: NEW_ORDER_DEFAULTS,
  })
  const { errors } = form.formState

  const { data: channelsData } = useChannels()
  const channels = channelsData?.data ?? []

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
      if (values.channel_id) payload.channel_id = values.channel_id
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
                    {/* Combobox rather than a bare input over a list of
                        buttons: arrow-key navigation, `aria-activedescendant`
                        and Enter-to-pick come from the primitive. Selecting
                        adds the row and clears the field, so no value is
                        held — the picker is an action, not a bound input. */}
                    <ResourceCombobox<Variant>
                      queryKey="new-order-variant-picker"
                      value=""
                      onChange={(id) => {
                        const variant = id ? variantById.current.get(id) : undefined
                        if (variant) addItem(variant)
                      }}
                      search={async (query) => {
                        const res = await adminClient.variants.list({ search: query, limit: 8 })
                        for (const v of res.data) variantById.current.set(v.id, v)
                        return res
                      }}
                      hydrate={async () => ({ data: [] })}
                      getOptionLabel={(v) => v.product_name ?? v.sku ?? v.id}
                      renderOption={(v) => (
                        <div className="flex flex-col">
                          <span className="font-medium">{v.product_name ?? v.sku ?? v.id}</span>
                          <span className="text-xs text-muted-foreground">
                            SKU {v.sku} · {formatPrice(v.price)}
                          </span>
                        </div>
                      )}
                      placeholder={t('admin.pages.orders.new.search_variant')}
                    />
                  </Field>
                </FieldGroup>

                {items.length > 0 && (
                  <div className="mt-4 overflow-x-auto">
                    <Table roundedBottom>
                      <TableHeader>
                        <TableRow>
                          <TableHead>{t('admin.orders.new.items_table.variant')}</TableHead>
                          <TableHead>{t('admin.orders.new.items_table.sku')}</TableHead>
                          <TableHead className="text-right">
                            {t('admin.orders.new.items_table.qty')}
                          </TableHead>
                          <TableHead className="w-10" />
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {items.map(({ variant, quantity }) => (
                          <TableRow key={variant.id}>
                            <TableCell className="font-medium">
                              {variant.product_name ?? variant.sku ?? variant.id}
                            </TableCell>
                            <TableCell className="text-muted-foreground">{variant.sku}</TableCell>
                            <TableCell className="text-right">
                              <Input
                                type="number"
                                min={1}
                                value={quantity}
                                onChange={(e) => updateQuantity(variant.id, Number(e.target.value))}
                                className="w-20 text-right ml-auto"
                              />
                            </TableCell>
                            <TableCell className="text-right">
                              <Button
                                type="button"
                                size="icon-xs"
                                variant="ghost"
                                onClick={() => removeItem(variant.id)}
                              >
                                <TrashIcon className="size-4" />
                                <span className="sr-only">{t('admin.actions.remove')}</span>
                              </Button>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
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

            {channels.length > 1 && (
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.fields.order.channel.label')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <Field>
                      <ChannelSelect
                        value={form.watch('channel_id') || ''}
                        onChange={(v) => form.setValue('channel_id', v, { shouldDirty: true })}
                        placeholder={t('admin.fields.order.channel.placeholder')}
                      />
                      <span className="text-xs text-muted-foreground">
                        {t('admin.fields.order.channel.help')}
                      </span>
                    </Field>
                  </FieldGroup>
                </CardContent>
              </Card>
            )}

            <Card>
              <CardHeader>
                <CardTitle>{t('admin.fields.discount.label')}</CardTitle>
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
