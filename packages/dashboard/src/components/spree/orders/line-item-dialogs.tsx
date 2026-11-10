import type { Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice, useResourceKey } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  Item,
  ItemActions,
  ItemContent,
  ProductIdentity,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { XCircleIcon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Catalog picker for an order's items, on the edit screen and the new-order
 * form. It writes nothing — the chosen variant and quantity are handed back to
 * the caller, which stages them until the merchant saves.
 */
export function AddLineItemDialog({
  searchParams,
  open,
  onOpenChange,
  onSelect,
}: {
  /**
   * Who is buying, where: `{ order_id }` for an existing order, or the market,
   * channel, buyer and currency of one being created. Lists only what that
   * buyer can be sold, priced as they would pay.
   */
  searchParams: Record<string, unknown>
  open: boolean
  onOpenChange: (open: boolean) => void
  onSelect: (variant: Variant, quantity: number) => void
}) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [selectedVariant, setSelectedVariant] = useState<Variant | null>(null)
  const [quantity, setQuantity] = useState(1)

  const { data: variantsData } = useQuery({
    queryKey: useResourceKey('variants', { picker: searchParams, search }),
    queryFn: () => adminClient.variants.list({ search, limit: 10, ...searchParams }),
    enabled: search.length >= 3,
    staleTime: 30_000,
  })

  const variants = variantsData?.data ?? []

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    e.stopPropagation()
    if (!selectedVariant) return
    onSelect(selectedVariant, quantity)
    onOpenChange(false)
    setSelectedVariant(null)
    setSearch('')
    setQuantity(1)
  }

  // A variant's options and SKU on one line, under its product's name.
  const variantDetails = (variant: Variant) =>
    [
      variant.options_text,
      `${t('admin.orders.detail.variant_search.sku_prefix')}: ${variant.sku || '—'}`,
    ]
      .filter(Boolean)
      .join(' · ')

  return (
    <Sheet open={open} onOpenChange={(o) => onOpenChange(o as boolean)}>
      <SheetContent side="right">
        <SheetHeader>
          <SheetTitle>{t('admin.orders.detail.add_line_item.title')}</SheetTitle>
          <SheetDescription>{t('admin.orders.detail.variant_search.description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
          <div className="flex-1 overflow-y-auto p-4">
            <FieldGroup>
              <Field>
                <FieldLabel>{t('admin.orders.detail.variant_search.label')}</FieldLabel>
                <Input
                  placeholder={t('admin.orders.detail.variant_search.placeholder')}
                  value={search}
                  onChange={(e) => {
                    setSearch(e.target.value)
                    setSelectedVariant(null)
                  }}
                  autoFocus
                />
                {search.length >= 3 && variants.length > 0 && !selectedVariant && (
                  <div className="mt-1 rounded-xl border border-border bg-popover text-popover-foreground shadow-xs max-h-[280px] overflow-y-auto">
                    {variants.map((v) => (
                      <button
                        key={v.id}
                        type="button"
                        onClick={() => {
                          setSelectedVariant(v)
                          setSearch('')
                        }}
                        className="flex w-full items-center gap-3 px-3 py-2.5 text-left text-base hover:bg-accent transition-colors border-b last:border-0"
                      >
                        <ProductIdentity
                          name={v.product_name ?? v.sku}
                          subtitle={variantDetails(v)}
                          thumbnailUrl={v.thumbnail_url}
                          className="flex-1"
                        />
                        <div className="text-base font-medium whitespace-nowrap">
                          {formatPrice(v.price)}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
                {search.length >= 3 && variants.length === 0 && !selectedVariant && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    {t('admin.orders.detail.variant_search.empty')}
                  </p>
                )}
              </Field>

              {selectedVariant && (
                <Item variant="outline" className="border-primary/30 bg-primary/5">
                  <ItemContent className="min-w-0">
                    <ProductIdentity
                      name={selectedVariant.product_name ?? selectedVariant.sku}
                      subtitle={`${variantDetails(selectedVariant)} · ${formatPrice(selectedVariant.price)}`}
                      thumbnailUrl={selectedVariant.thumbnail_url}
                    />
                  </ItemContent>
                  <ItemActions>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon-xs"
                      onClick={() => setSelectedVariant(null)}
                      aria-label={t('admin.a11y.clear_selection')}
                    >
                      <XCircleIcon className="size-4" />
                    </Button>
                  </ItemActions>
                </Item>
              )}

              <Field>
                <FieldLabel htmlFor="quantity">{t('admin.fields.quantity.label')}</FieldLabel>
                <Input
                  id="quantity"
                  type="number"
                  min={1}
                  value={quantity}
                  onChange={(e) => setQuantity(Number(e.target.value) || 1)}
                />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={!selectedVariant}>
              {t('admin.actions.add')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
