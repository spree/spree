import type { Customer, Variant } from '@spree/admin-sdk'
import { useMutation, useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { TrashIcon, XIcon } from 'lucide-react'
import { type FormEvent, useState } from 'react'
import { adminClient } from '@/client'
import { PageHeader } from '@/components/spree/page-header'
import { ResourceLayout } from '@/components/spree/resource-layout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'

export const Route = createFileRoute('/_authenticated/$storeId/orders/new')({
  component: NewOrderPage,
})

interface PendingItem {
  variant: Variant
  quantity: number
}

function NewOrderPage() {
  const { storeId } = Route.useParams()
  const navigate = useNavigate()

  const [customer, setCustomer] = useState<Customer | null>(null)
  const [customerSearch, setCustomerSearch] = useState('')
  const [email, setEmail] = useState('')
  const [items, setItems] = useState<PendingItem[]>([])
  const [variantSearch, setVariantSearch] = useState('')
  const [useDefaultAddress, setUseDefaultAddress] = useState(true)
  const [internalNote, setInternalNote] = useState('')
  const [customerNote, setCustomerNote] = useState('')
  const [couponCode, setCouponCode] = useState('')

  // Customer typeahead
  const { data: customersData } = useQuery({
    queryKey: ['customers', 'search', customerSearch],
    queryFn: () => adminClient.customers.list({ search: customerSearch, limit: 8 }),
    enabled: !customer && customerSearch.length >= 2,
    staleTime: 30_000,
  })
  const customerResults = customersData?.data ?? []

  // Variant typeahead
  const { data: variantsData } = useQuery({
    queryKey: ['variants', 'search', variantSearch],
    queryFn: () => adminClient.variants.list({ search: variantSearch, limit: 8 }),
    enabled: variantSearch.length >= 3,
    staleTime: 30_000,
  })
  const variantResults = variantsData?.data ?? []

  const createMutation = useMutation({
    mutationFn: () => {
      const payload: Record<string, unknown> = {
        items: items.map((i) => ({ variant_id: i.variant.id, quantity: i.quantity })),
      }
      if (customer) {
        payload.customer_id = customer.id
        payload.use_customer_default_address = useDefaultAddress
      } else if (email) {
        payload.email = email
      }
      if (internalNote) payload.internal_note = internalNote
      if (customerNote) payload.customer_note = customerNote
      if (couponCode) payload.coupon_code = couponCode
      return adminClient.orders.create(payload)
    },
    onSuccess: (order) => {
      navigate({ to: '/$storeId/orders/$orderId', params: { storeId, orderId: order.id } })
    },
  })

  const canSubmit = (Boolean(customer) || email.length > 0) && !createMutation.isPending

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!canSubmit) return
    createMutation.mutate()
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
    <form onSubmit={handleSubmit}>
      <ResourceLayout
        header={<PageHeader title="New Order" backTo="orders/drafts" />}
        main={
          <>
            <Card>
              <CardHeader>
                <CardTitle>Customer</CardTitle>
              </CardHeader>
              <CardContent>
                {customer ? (
                  <div className="flex items-center justify-between rounded-md border p-3">
                    <div>
                      <div className="font-medium">{customer.email}</div>
                      {(customer.first_name || customer.last_name) && (
                        <div className="text-sm text-muted-foreground">
                          {[customer.first_name, customer.last_name].filter(Boolean).join(' ')}
                        </div>
                      )}
                    </div>
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={() => {
                        setCustomer(null)
                        setCustomerSearch('')
                      }}
                    >
                      <XIcon className="size-4" />
                      Change
                    </Button>
                  </div>
                ) : (
                  <FieldGroup>
                    <Field>
                      <FieldLabel>Search by email or name</FieldLabel>
                      <Input
                        placeholder="Type 2+ chars to search…"
                        value={customerSearch}
                        onChange={(e) => setCustomerSearch(e.target.value)}
                      />
                      {customerSearch.length >= 2 && customerResults.length > 0 && (
                        <div className="mt-1 rounded-lg border border-border bg-popover text-popover-foreground shadow-xs max-h-[280px] overflow-y-auto">
                          {customerResults.map((c) => (
                            <button
                              key={c.id}
                              type="button"
                              onClick={() => {
                                setCustomer(c)
                                setCustomerSearch('')
                              }}
                              className="block w-full px-3 py-2.5 text-left text-sm hover:bg-muted transition-colors border-b last:border-0"
                            >
                              <div className="font-medium">{c.email}</div>
                              {(c.first_name || c.last_name) && (
                                <div className="text-xs text-muted-foreground">
                                  {[c.first_name, c.last_name].filter(Boolean).join(' ')}
                                </div>
                              )}
                            </button>
                          ))}
                        </div>
                      )}
                    </Field>
                    <Field>
                      <FieldLabel>Or use a guest email</FieldLabel>
                      <Input
                        type="email"
                        placeholder="customer@example.com"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                      />
                    </Field>
                  </FieldGroup>
                )}

                {customer && (
                  <div className="mt-4 flex items-center gap-3">
                    <Switch checked={useDefaultAddress} onCheckedChange={setUseDefaultAddress} />
                    <span className="text-sm">
                      Use customer's default billing & shipping addresses
                    </span>
                  </div>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Items</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel>Add a variant</FieldLabel>
                    <Input
                      placeholder="Search by name or SKU (3+ chars)…"
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
                              SKU {v.sku} · {v.display_price ?? '—'}
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
                          <th className="p-3 pl-5 text-left font-normal">Variant</th>
                          <th className="p-3 text-left font-normal">SKU</th>
                          <th className="p-3 text-right font-normal">Qty</th>
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
                <CardTitle>Notes</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="customer-note">
                      Customer note (visible to customer)
                    </FieldLabel>
                    <Textarea
                      id="customer-note"
                      rows={3}
                      value={customerNote}
                      onChange={(e) => setCustomerNote(e.target.value)}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="internal-note">Internal note (staff only)</FieldLabel>
                    <Textarea
                      id="internal-note"
                      rows={3}
                      value={internalNote}
                      onChange={(e) => setInternalNote(e.target.value)}
                    />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Discount</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="coupon-code">Coupon code</FieldLabel>
                    <Input
                      id="coupon-code"
                      placeholder="Optional"
                      value={couponCode}
                      onChange={(e) => setCouponCode(e.target.value)}
                    />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="flex flex-col gap-3 pt-6">
                <Button type="submit" disabled={!canSubmit}>
                  {createMutation.isPending ? 'Creating…' : 'Create Order'}
                </Button>
                {createMutation.error && (
                  <p className="text-sm text-destructive">
                    {(createMutation.error as Error).message}
                  </p>
                )}
                <p className="text-xs text-muted-foreground">
                  Creates a draft order. Add payments and complete it after creation.
                </p>
              </CardContent>
            </Card>
          </>
        }
      />
    </form>
  )
}
