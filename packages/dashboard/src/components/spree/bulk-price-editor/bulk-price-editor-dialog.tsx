import type { PriceList } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogHeader,
  DialogTitle,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  useConfirm,
} from '@spree/dashboard-ui'
import { XIcon } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  BulkPriceEditor,
  type BulkPriceEditorState,
} from '@/components/spree/bulk-price-editor/bulk-price-editor'

interface BulkPriceEditorDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  priceList: PriceList
}

/**
 * Modal bulk price editor for a single price list. Body is the server-backed
 * `<BulkPriceEditor>` which reads `/admin/prices` and saves via
 * `/admin/prices/bulk_upsert`. Dirty state comes from the editor's internal
 * edits Map, reported via `onStateChange`.
 *
 * Product base prices are NOT edited through this dialog — they live inline
 * on the product page in `<PricesCard>`, riding the parent product form.
 *
 * Why a dialog instead of a route: editing prices is "deeper into this
 * thing", not "leave this thing to go elsewhere". The dialog preserves any
 * form state behind it (no remount on close).
 */
export function BulkPriceEditorDialog({
  open,
  onOpenChange,
  priceList,
}: BulkPriceEditorDialogProps) {
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
  const onStateChange = useCallback((next: BulkPriceEditorState) => {
    setEditorState(next)
  }, [])

  // Reset currency to the store default whenever the dialog reopens. Stale
  // currency state from a prior open would otherwise survive the
  // remount-less close+reopen.
  useEffect(() => {
    if (open) setCurrency(defaultCurrency)
  }, [open, defaultCurrency])

  const isDirty = editorState.dirtyCount > 0
  const isSaving = editorState.saving

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
        confirmLabel: t('admin.actions.discard_changes'),
      })
      if (!ok) return
      editorState.discard()
      onOpenChange(false)
    },
    [isDirty, editorState, confirm, onOpenChange, t],
  )

  // Currency switch discards pending edits — the working set is per-currency.
  const handleCurrencyChange = useCallback(
    async (next: string) => {
      if (next === currency) return
      if (editorState.dirtyCount > 0) {
        const ok = await confirm({
          title: t('admin.pages.products.price_lists.edit_prices.discard_confirm.title'),
          message: t(
            'admin.pages.products.price_lists.edit_prices.discard_confirm.message_currency',
          ),
          variant: 'destructive',
          confirmLabel: t('admin.actions.discard_changes'),
        })
        if (!ok) return
        editorState.discard()
      }
      setCurrency(next)
    },
    [currency, editorState, confirm, t],
  )

  const title = t('admin.pages.products.price_lists.edit_prices.title', { name: priceList.name })
  const dirtySummary = t('admin.pages.products.price_lists.edit_prices.dirty_summary', {
    count: editorState.dirtyCount,
  })

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
            {isDirty && <p className="mt-0.5 text-xs text-muted-foreground">{dirtySummary}</p>}
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
              disabled={!isDirty || isSaving}
              onClick={editorState.discard}
            >
              {t('admin.actions.discard')}
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={!isDirty || isSaving}
              onClick={() => editorState.save()}
            >
              {isSaving
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
            priceListId={priceList.id}
            currency={currency}
            onStateChange={onStateChange}
          />
        </DialogBody>
      </DialogContent>
    </Dialog>
  )
}
