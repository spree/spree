import type { Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice } from '@spree/dashboard-core'
import {
  Button,
  Field,
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
import { XCircleIcon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Catalog picker for the order edit screen. It writes nothing — the chosen
 * variant and quantity are handed back to the caller, which stages them as a
 * pending row until the merchant saves the order.
 */
export function AddLineItemDialog({
  open,
  onOpenChange,
  onSelect,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  onSelect: (variant: Variant, quantity: number) => void
}) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [selectedVariant, setSelectedVariant] = useState<Variant | null>(null)
  const [quantity, setQuantity] = useState(1)

  const { data: variantsData } = useQuery({
    queryKey: ['variants', 'search', search],
    queryFn: () => adminClient.variants.list({ search, limit: 10 }),
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
                  <div className="mt-1 rounded-lg border border-border bg-popover text-popover-foreground shadow-xs max-h-[280px] overflow-y-auto">
                    {variants.map((v) => (
                      <button
                        key={v.id}
                        type="button"
                        onClick={() => {
                          setSelectedVariant(v)
                          setSearch('')
                        }}
                        className="flex w-full items-center gap-3 px-3 py-2.5 text-left text-sm hover:bg-muted transition-colors border-b last:border-0"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="font-medium truncate">{v.product_name ?? v.sku}</div>
                          <div className="text-xs text-muted-foreground">
                            {v.options_text && <span>{v.options_text} · </span>}
                            {t('admin.orders.detail.variant_search.sku_prefix')}: {v.sku || '—'}
                          </div>
                        </div>
                        <div className="text-sm font-medium whitespace-nowrap">
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
                <div className="flex items-center justify-between rounded-lg border border-primary/30 bg-primary/5 p-3">
                  <div>
                    <div className="text-sm font-medium">
                      {selectedVariant.product_name ?? selectedVariant.sku}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      {selectedVariant.options_text && (
                        <span>{selectedVariant.options_text} · </span>
                      )}
                      {t('admin.orders.detail.variant_search.sku_prefix')}:{' '}
                      {selectedVariant.sku || '—'} · {formatPrice(selectedVariant.price)}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setSelectedVariant(null)}
                    className="rounded p-1 text-muted-foreground hover:bg-accent hover:text-foreground"
                    aria-label={t('admin.a11y.clear_selection')}
                  >
                    <XCircleIcon className="size-4" />
                  </button>
                </div>
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
