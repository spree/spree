import type { PriceList, Product } from '@spree/admin-sdk'
import { XIcon } from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  BulkPriceEditor,
  type BulkPriceEditorState,
} from '@/components/spree/bulk-price-editor/bulk-price-editor'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useStore } from '@/providers/store-provider'

/**
 * Discriminator for what the dialog edits.
 *
 * - `price_list`: override prices for one price list. Editor filters to
 *   `price_list_id_eq` and ships `price_list_id` on save.
 * - `product`: base prices (no price list) restricted to one product's
 *   variants. Editor filters to `variant_product_id_eq` + `price_list_id_null`
 *   and omits `price_list_id` on save.
 */
export type BulkPriceEditorScope =
  | { kind: 'price_list'; priceList: PriceList }
  | { kind: 'product'; product: Pick<Product, 'id' | 'name'> }

interface BulkPriceEditorDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  scope: BulkPriceEditorScope
}

/**
 * Modal bulk price editor. The dialog chrome (header, currency picker,
 * discard/save buttons, dirty-close guard) is identical regardless of
 * scope — only the title and the predicates forwarded to the editor
 * change. `kind: 'price_list'` edits overrides for one list; `kind:
 * 'product'` edits the base prices (price_list_id IS NULL) of one
 * product's variants.
 *
 * Why a dialog instead of a route: editing prices is "deeper into this
 * thing", not "leave this thing to go elsewhere". The dialog preserves
 * the form's state behind it (no remount on close).
 */
export function BulkPriceEditorDialog({ open, onOpenChange, scope }: BulkPriceEditorDialogProps) {
  const { t } = useTranslation()
  const { currencies, defaultCurrency } = useStore()
  const confirm = useConfirm()

  const [currency, setCurrency] = useState(defaultCurrency)
  const [editorState, setEditorState] = useState<BulkPriceEditorState>({
    dirtyCount: 0,
    saving: false,
    save: async () => false,
    discard: () => {},
  })

  const isDirty = editorState.dirtyCount > 0

  // Switch (not ternary) so adding a third `kind` becomes a TS error
  // instead of silently falling into the product branch.
  const { title, priceListId, editorFilter } = useMemo(() => {
    switch (scope.kind) {
      case 'price_list':
        return {
          title: t('admin.pages.products.price_lists.edit_prices.title', {
            name: scope.priceList.name,
          }),
          priceListId: scope.priceList.id,
          editorFilter: undefined,
        }
      case 'product':
        return {
          title: t('admin.pages.products.edit.bulk_prices.dialog_title', {
            name: scope.product.name,
          }),
          priceListId: undefined,
          editorFilter: { variant_product_id_eq: scope.product.id },
        }
    }
  }, [scope, t])

  const onStateChange = useCallback((next: BulkPriceEditorState) => {
    setEditorState(next)
  }, [])

  // Reset currency to the store default whenever the dialog reopens.
  // Stale currency state from a prior open would otherwise survive the
  // remount-less close+reopen.
  useEffect(() => {
    if (open) setCurrency(defaultCurrency)
  }, [open, defaultCurrency])

  // Guarded close — ESC / backdrop click / X button all funnel through
  // `onOpenChange(false)`. If there are dirty edits, confirm first.
  const handleOpenChange = useCallback(
    async (next: boolean) => {
      if (next) {
        onOpenChange(true)
        return
      }
      if (!isDirty) {
        onOpenChange(false)
        return
      }
      const ok = await confirm({
        title: t('admin.pages.products.price_lists.edit_prices.discard_confirm.title'),
        message: t('admin.pages.products.price_lists.edit_prices.discard_confirm.message_close', {
          count: editorState.dirtyCount,
        }),
        variant: 'destructive',
        confirmLabel: t('admin.pages.products.price_lists.edit_prices.discard_confirm.confirm'),
      })
      if (ok) {
        // Drop pending edits before closing — the dialog isn't remounted
        // on close, so stale edits would otherwise survive a reopen.
        editorState.discard()
        onOpenChange(false)
      }
    },
    [isDirty, editorState, confirm, onOpenChange, t],
  )

  const handleCurrencyChange = useCallback(
    async (next: string) => {
      if (next === currency) return
      if (isDirty) {
        const ok = await confirm({
          title: t('admin.pages.products.price_lists.edit_prices.discard_confirm.title'),
          message: t(
            'admin.pages.products.price_lists.edit_prices.discard_confirm.message_currency',
          ),
          variant: 'destructive',
          confirmLabel: t('admin.pages.products.price_lists.edit_prices.discard_confirm.confirm'),
        })
        if (!ok) return
        // Same reason as the close path — strand the pending edits or
        // they'd persist across the currency switch.
        editorState.discard()
      }
      setCurrency(next)
    },
    [currency, isDirty, editorState, confirm, t],
  )

  return (
    <Dialog open={open} onOpenChange={(next) => handleOpenChange(next)} modal>
      <DialogContent
        // Edge-to-edge minus a 3-unit (0.75rem) gutter on all sides.
        // The primitive ships `top-1/2 left-1/2 -translate-1/2` (centered
        // popup) and inline `maxHeight: 90vh`. We override all four
        // insets with `!` utilities, zero the translate, and pass
        // `maxHeight: 'none'` to beat the inline style — together those
        // let the popup actually stretch between top-3 / bottom-3 / left-3
        // / right-3 instead of collapsing to its content size.
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        <DialogHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b p-3">
          <div className="min-w-0">
            <DialogTitle className="truncate">{title}</DialogTitle>
            {isDirty && (
              <p className="mt-0.5 text-xs text-muted-foreground">
                {t('admin.pages.products.price_lists.edit_prices.dirty_summary', {
                  count: editorState.dirtyCount,
                })}
              </p>
            )}
          </div>
          <div className="flex items-center gap-2">
            <Select value={currency} onValueChange={handleCurrencyChange}>
              <SelectTrigger size="sm" className="w-24">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {currencies.map((c) => (
                  <SelectItem key={c} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              disabled={!isDirty || editorState.saving}
              onClick={() => editorState.discard()}
            >
              {t('admin.actions.discard')}
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={!isDirty || editorState.saving}
              onClick={() => editorState.save()}
            >
              {editorState.saving
                ? t('admin.actions.saving')
                : t('admin.pages.products.price_lists.edit_prices.save_cta')}
            </Button>
            <Button
              type="button"
              size="icon-sm"
              variant="ghost"
              onClick={() => handleOpenChange(false)}
              aria-label={t('admin.actions.close')}
            >
              <XIcon />
            </Button>
          </div>
        </DialogHeader>
        <DialogBody className="flex min-h-0 flex-1 flex-col p-3">
          <BulkPriceEditor
            priceListId={priceListId}
            currency={currency}
            filter={editorFilter}
            onStateChange={onStateChange}
          />
        </DialogBody>
      </DialogContent>
    </Dialog>
  )
}
