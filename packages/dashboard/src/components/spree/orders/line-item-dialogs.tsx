import type { Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
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
import { useQuery } from '@tanstack/react-query'
import { XCircleIcon } from 'lucide-react'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

/** Searches the catalog and adds the chosen variant to the order. */
export function AddLineItemDialog({
  orderId,
  open,
  onOpenChange,
}: {
  orderId: string
  open: boolean
  onOpenChange: (open: boolean) => void
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

  const mutation = useOrderMutation(orderId, (params: { variant_id: string; quantity: number }) =>
    adminClient.orders.items.create(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!selectedVariant) return
    mutation.mutate(
      { variant_id: selectedVariant.id, quantity },
      {
        onSuccess: () => {
          onOpenChange(false)
          setSelectedVariant(null)
          setSearch('')
          setQuantity(1)
        },
      },
    )
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
            <Button type="submit" disabled={!selectedVariant || mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

/** Changes how many units of one line item the order carries. */
export function EditQuantityDialog({
  orderId,
  lineItemId,
  currentQuantity,
  open,
  onOpenChange,
}: {
  orderId: string
  lineItemId: string
  currentQuantity: number
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const mutation = useOrderMutation(orderId, (params: { quantity: number }) =>
    adminClient.orders.items.update(orderId, lineItemId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { quantity: Number(fd.get('quantity')) || 1 },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.edit_quantity.title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.edit_quantity.description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="edit-quantity">{t('admin.fields.quantity.label')}</FieldLabel>
                <Input
                  id="edit-quantity"
                  name="quantity"
                  type="number"
                  min={1}
                  defaultValue={currentQuantity}
                />
              </Field>
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
