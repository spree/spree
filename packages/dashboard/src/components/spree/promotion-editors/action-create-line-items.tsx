import type { Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice, ResourceCombobox } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { TrashIcon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EditorShell } from './editor-shell'
import type { PromotionActionEditorContext, PromotionActionLineItemParams } from './types'

interface LineItemDraft extends PromotionActionLineItemParams {
  variant?: Variant
}

export function CreateLineItemsActionEditor({
  draft,
  onSave,
  onClose,
}: PromotionActionEditorContext) {
  const { t } = useTranslation()
  const initialIds = useMemo(
    () => (draft.line_items ?? []).map((row) => row.variant_id),
    [draft.line_items],
  )
  const variantById = useRef(new Map<string, Variant>())

  const { data: loadedVariants = [], isLoading: variantsLoading } = useQuery({
    queryKey: ['promotion-create-line-items-variants', initialIds],
    queryFn: async () => {
      const variants = await Promise.all(
        initialIds.map(async (id) => {
          try {
            return await adminClient.variants.get(id)
          } catch {
            return null
          }
        }),
      )
      for (const variant of variants) {
        if (variant) variantById.current.set(variant.id, variant)
      }
      return variants.filter(Boolean) as Variant[]
    },
    enabled: initialIds.length > 0,
    staleTime: Number.POSITIVE_INFINITY,
  })

  const [lineItems, setLineItems] = useState<LineItemDraft[]>(() =>
    (draft.line_items ?? []).map((row) => ({
      variant_id: row.variant_id,
      quantity: row.quantity,
    })),
  )

  const resolvedLineItems = useMemo(
    () =>
      lineItems.map((row) => ({
        ...row,
        variant:
          row.variant ??
          variantById.current.get(row.variant_id) ??
          loadedVariants.find((variant) => variant.id === row.variant_id),
      })),
    [lineItems, loadedVariants],
  )

  function addVariant(variant: Variant) {
    setLineItems((current) => {
      const existing = current.find((row) => row.variant_id === variant.id)
      if (existing) {
        return current.map((row) =>
          row.variant_id === variant.id ? { ...row, quantity: row.quantity + 1, variant } : row,
        )
      }
      variantById.current.set(variant.id, variant)
      return [...current, { variant_id: variant.id, quantity: 1, variant }]
    })
  }

  function updateQuantity(variantId: string, quantity: number) {
    const nextQuantity = Number.isFinite(quantity) && quantity > 0 ? Math.floor(quantity) : 1
    setLineItems((current) =>
      current.map((row) =>
        row.variant_id === variantId ? { ...row, quantity: nextQuantity } : row,
      ),
    )
  }

  function removeVariant(variantId: string) {
    setLineItems((current) => current.filter((row) => row.variant_id !== variantId))
  }

  function handleSave() {
    onSave({
      ...draft,
      line_items: lineItems.map(({ variant_id, quantity }) => ({ variant_id, quantity })),
    })
    onClose()
  }

  return (
    <EditorShell
      onSave={handleSave}
      onCancel={onClose}
      pending={variantsLoading}
      saveDisabled={lineItems.length === 0}
    >
      <p className="text-sm text-muted-foreground">
        {t('admin.components.create_line_items_action_editor.description')}
      </p>

      {resolvedLineItems.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {t('admin.components.create_line_items_action_editor.empty')}
        </p>
      ) : (
        <div className="overflow-x-auto">
          <Table roundedBottom>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.orders.new.items_table.variant')}</TableHead>
                <TableHead>{t('admin.orders.new.items_table.sku')}</TableHead>
                <TableHead className="text-right">{t('admin.fields.quantity.label')}</TableHead>
                <TableHead className="w-10" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {resolvedLineItems.map((row) => (
                <TableRow key={row.variant_id}>
                  <TableCell className="font-medium">
                    {row.variant?.product_name ?? row.variant?.sku ?? row.variant_id}
                  </TableCell>
                  <TableCell className="text-muted-foreground">{row.variant?.sku ?? '—'}</TableCell>
                  <TableCell className="text-right">
                    <Input
                      type="number"
                      min={1}
                      value={row.quantity}
                      onChange={(event) =>
                        updateQuantity(row.variant_id, Number(event.target.value))
                      }
                      className="ml-auto w-20 text-right"
                    />
                  </TableCell>
                  <TableCell className="text-right">
                    <Button
                      type="button"
                      size="icon-xs"
                      variant="ghost"
                      onClick={() => removeVariant(row.variant_id)}
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

      <FieldGroup>
        <Field>
          <FieldLabel>
            {t('admin.components.create_line_items_action_editor.variant_label')}
          </FieldLabel>
          <ResourceCombobox<Variant>
            queryKey="promotion-create-line-items-variant-picker"
            value=""
            onChange={(id) => {
              const variant = id ? variantById.current.get(id) : undefined
              if (variant) addVariant(variant)
            }}
            search={async (query) => {
              const res = await adminClient.variants.list({ search: query, limit: 8 })
              for (const variant of res.data) variantById.current.set(variant.id, variant)
              return res
            }}
            hydrate={async () => ({ data: [] })}
            getOptionLabel={(variant) => variant.product_name ?? variant.sku ?? variant.id}
            renderOption={(variant) => (
              <div className="flex flex-col">
                <span className="font-medium">
                  {variant.product_name ?? variant.sku ?? variant.id}
                </span>
                <span className="text-xs text-muted-foreground">
                  {variant.options_text && <span>{variant.options_text} · </span>}
                  {t('admin.orders.detail.variant_search.sku_prefix')}: {variant.sku || '—'} ·{' '}
                  {formatPrice(variant.price)}
                </span>
              </div>
            )}
            placeholder={t('admin.components.create_line_items_action_editor.search_placeholder')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
