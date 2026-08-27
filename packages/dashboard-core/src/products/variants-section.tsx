import {
  closestCenter,
  DndContext,
  type DragEndEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { ProductFormValues, VariantFormValues } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  DragHandle,
  Input,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { PencilIcon, XIcon } from 'lucide-react'
import { type CSSProperties, useEffect, useMemo, useState } from 'react'
import { type UseFormReturn, useFieldArray, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { PanelOptionType as OptionType } from '../api-client'
import { BulkVariantsDialog } from './bulk-variants-dialog'
import {
  useFormOptionTypes as useOptionTypes,
  useFormOptionTypesByIds as useOptionTypesByIds,
  useFormProductType as useProductType,
} from './use-product-form-data'
import { VariantEditSheet } from './variant-edit-sheet'
import {
  generateVariantCombinations,
  optionsKey,
  reconcileVariants,
  type SelectedOptionType,
  variantDisplayLabel,
} from './variants-matrix'
import { VariantsOptionsBuilder } from './variants-options-builder'

interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  /**
   * Offer the product type's option types as empty rows when the product has
   * none of its own. New products only — a saved product's option set is
   * whatever it already has.
   */
  seedFromType?: boolean
}

// Derive the initial selected option types from current variant rows so the
// builder picks up where the merchant left off. Names come from variant
// options; labels + ids are looked up against the global option-type registry.
function deriveSelectedFromVariants(
  variants: VariantFormValues[],
  allOptionTypes: OptionType[],
): SelectedOptionType[] {
  const namesInOrder: string[] = []
  const valuesByName = new Map<string, Set<string>>()

  variants.forEach((v) => {
    v.options.forEach((o) => {
      if (!valuesByName.has(o.name)) {
        valuesByName.set(o.name, new Set())
        namesInOrder.push(o.name)
      }
      valuesByName.get(o.name)?.add(o.value)
    })
  })

  return namesInOrder
    .map<SelectedOptionType | null>((name, idx) => {
      const ot = allOptionTypes.find((x) => x.name === name)
      if (!ot) return null
      return {
        id: ot.id,
        name: ot.name,
        label: ot.label,
        position: ot.position ?? idx,
        values: Array.from(valuesByName.get(name) ?? []).map((value) => ({
          name: value,
          label: ot.option_values?.find((ov) => ov.name === value)?.label,
        })),
      }
    })
    .filter((x): x is SelectedOptionType => x !== null)
}

// Empty rows for a product type's option types — a starting point, not state.
function seedFromProductType(
  optionTypeIds: string[],
  allOptionTypes: OptionType[],
): SelectedOptionType[] {
  return optionTypeIds
    .map<SelectedOptionType | null>((id, idx) => {
      const optionType = allOptionTypes.find((candidate) => candidate.id === id)
      if (!optionType) return null

      return {
        id: optionType.id,
        name: optionType.name,
        label: optionType.label,
        position: optionType.position ?? idx,
        values: [],
      }
    })
    .filter((entry): entry is SelectedOptionType => entry !== null)
}

export function VariantsSection({ form, seedFromType = false }: Props) {
  const { t } = useTranslation()
  const { data: optionTypesData } = useOptionTypes()
  const allOptionTypes = useMemo(() => optionTypesData?.data ?? [], [optionTypesData])
  const productTypeId = form.watch('product_type_id') as string | null | undefined
  const { data: productType } = useProductType(productTypeId ?? undefined)
  // Resolved by id rather than read out of `allOptionTypes`, whose first page
  // may not contain every option type the product type references.
  const { data: typeOptionTypesData } = useOptionTypesByIds(productType?.option_type_ids)
  const typeOptionTypes = useMemo(() => typeOptionTypesData?.data ?? [], [typeOptionTypesData])

  const variantsArray = useFieldArray<ProductFormValues, 'variants', '_key'>({
    control: form.control,
    name: 'variants',
    keyName: '_key',
  })

  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const [sheetOpen, setSheetOpen] = useState(false)
  const [bulkOpen, setBulkOpen] = useState(false)
  const [orphanedKeys, setOrphanedKeys] = useState<string[]>([])

  // `selected` is fully derived from the current variants array + the global
  // option-type registry. Changes flow: builder → handleOptionsChange writes
  // RHF variants → next render derives `selected` from the new variants. No
  // local state to drift out of sync.
  const watchedVariants = useWatch({ control: form.control, name: 'variants' })
  const derived = useMemo(
    () => deriveSelectedFromVariants(watchedVariants ?? [], allOptionTypes),
    [watchedVariants, allOptionTypes],
  )

  // A product type's option types are *offered* as empty rows, once, when the
  // merchant picks the type on a new product. They live in local state rather
  // than being derived every render: an empty row writes no variants, so a
  // derived version would regenerate itself the moment the merchant removed it.
  // Once any row has values the variants array takes over as the source.
  const [offeredOptionTypes, setOfferedOptionTypes] = useState<SelectedOptionType[]>([])
  const [offeredForTypeId, setOfferedForTypeId] = useState<string | null>(null)

  useEffect(() => {
    // Clearing the type withdraws the offer; anything the merchant built is in
    // `derived` and unaffected.
    if (!productTypeId) {
      if (offeredForTypeId !== null) {
        setOfferedForTypeId(null)
        setOfferedOptionTypes([])
      }
      return
    }

    if (!seedFromType || productTypeId === offeredForTypeId) return
    // Only on a product the merchant hasn't started building options for.
    if (derived.length > 0) return
    // Both queries must have landed. Marking the type seeded off an empty
    // registry would offer nothing and never retry once the data arrives.
    if (!productType) return
    // Nothing to offer until the type's own option types have resolved.
    const configuredIds = productType.option_type_ids ?? []
    if (configuredIds.length > 0 && typeOptionTypes.length === 0) return

    setOfferedForTypeId(productTypeId)
    setOfferedOptionTypes(seedFromProductType(configuredIds, typeOptionTypes))
  }, [seedFromType, productTypeId, offeredForTypeId, derived.length, productType, typeOptionTypes])

  const selected = derived.length > 0 ? derived : offeredOptionTypes

  const fields = variantsArray.fields
  const hasOptionTypes = selected.length > 0
  const isSimpleProduct = !hasOptionTypes && fields.length <= 1
  // Options are being defined but none have values yet, so the only variant is
  // the option-less placeholder. Showing it as "Default variant" next to a
  // half-filled option row reads like a real row the merchant should edit.
  const awaitingOptionValues =
    hasOptionTypes && selected.every((optionType) => optionType.values.length === 0)

  const handleOptionsChange = (next: SelectedOptionType[]) => {
    // Keep the offered rows in step with the builder — including a removal,
    // which must not be undone by the seeding effect above.
    setOfferedOptionTypes(next)

    const combinations = generateVariantCombinations(next)
    const existing = form.getValues('variants') ?? []
    if (combinations.length === 0) {
      // No options selected — drop all option-bearing variants down to a
      // single default-variant row so the product remains purchasable. Keep
      // a persisted id when possible so the existing default is reused, and
      // carry stock_levels forward. The inventory grid fills any gaps for
      // locations the default doesn't already cover (find-or-create on edit).
      const carry = existing[0]
      const defaultRow: VariantFormValues = {
        ...(carry?.id ? { id: carry.id } : {}),
        sku: carry?.sku ?? null,
        barcode: carry?.barcode ?? null,
        position: 0,
        options: [],
        weight: carry?.weight ?? null,
        height: carry?.height ?? null,
        width: carry?.width ?? null,
        depth: carry?.depth ?? null,
        weight_unit: carry?.weight_unit ?? null,
        dimensions_unit: carry?.dimensions_unit ?? null,
        track_inventory: carry?.track_inventory ?? true,
        tax_category_id: carry?.tax_category_id ?? null,
        prices: carry?.prices ?? [],
        stock_levels: carry?.stock_levels ?? [],
      }
      form.setValue('variants', [defaultRow], { shouldDirty: true })
      setOrphanedKeys([])
      return
    }
    const { next: nextVariants, orphanedKeys: nextOrphaned } = reconcileVariants(
      existing,
      combinations,
    )
    form.setValue('variants', nextVariants, { shouldDirty: true })
    setOrphanedKeys(nextOrphaned)
  }

  const handleConfirmDropOrphans = () => {
    const existing = form.getValues('variants') ?? []
    const orphanedSet = new Set(orphanedKeys)
    const filtered = existing.filter((v) => !orphanedSet.has(optionsKey(v.options)))
    const reindexed = filtered.map((v, i) => ({ ...v, position: i }))
    form.setValue('variants', reindexed, { shouldDirty: true })
    setOrphanedKeys([])
  }

  const handleKeepOrphans = () => {
    // Re-merge orphaned variants back in. They were never actually removed
    // from form state — orphanedKeys is just a list of options-keys that
    // DON'T match a generated combination. Clearing the banner is the only
    // action needed.
    setOrphanedKeys([])
  }

  const handleRowRemove = (index: number) => {
    // If the removed row was in the orphan list, drop its key from
    // `orphanedKeys` too — otherwise the banner's count ("N variants no
    // longer match…") outlives the row and reports a stale number. The
    // visible list filters missing rows out via `orphanedEntries`, but the
    // count reads `orphanedKeys.length` directly so the two get out of sync.
    const removed = form.getValues(`variants.${index}`)
    if (removed) {
      const removedKey = optionsKey(removed.options ?? [])
      setOrphanedKeys((prev) => prev.filter((k) => k !== removedKey))
    }
    variantsArray.remove(index)
    // Reindex remaining rows so position reflects array order.
    const remaining = form.getValues('variants') ?? []
    remaining.forEach((_, i) => {
      form.setValue(`variants.${i}.position`, i)
    })
  }

  const handleEditRow = (index: number) => {
    setEditingIndex(index)
    setSheetOpen(true)
  }

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const fromIndex = fields.findIndex((f) => f._key === active.id)
    const toIndex = fields.findIndex((f) => f._key === over.id)
    if (fromIndex === -1 || toIndex === -1) return
    variantsArray.move(fromIndex, toIndex)
    // Rewrite position to match the new order — the API uses position to
    // order the variants array and acts_as_list keys off it server-side.
    const reordered = form.getValues('variants') ?? []
    reordered.forEach((_, i) => {
      form.setValue(`variants.${i}.position`, i)
    })
  }

  // Pair each orphan key with its display label so the list can key by the
  // options-key (uniquely identifies an orphan row in form state regardless
  // of save status).
  const orphanedEntries = useMemo(() => {
    const existing = form.getValues('variants') ?? []
    const byKey = new Map<string, VariantFormValues>()
    existing.forEach((v) => {
      byKey.set(optionsKey(v.options), v)
    })
    return orphanedKeys
      .map((key) => {
        const variant = byKey.get(key)
        if (!variant) return null
        return {
          key,
          label: variantDisplayLabel(
            variant,
            t('admin.products.variants.default_variant'),
            allOptionTypes,
          ),
        }
      })
      .filter((entry): entry is { key: string; label: string } => entry !== null)
  }, [orphanedKeys, form, t, allOptionTypes])

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-3 space-y-0">
        <CardTitle>{t('admin.products.variants.title')}</CardTitle>
        {fields.length > 0 && (
          <Button type="button" variant="outline" size="sm" onClick={() => setBulkOpen(true)}>
            {t('admin.products.variants.bulk_edit.trigger')}
          </Button>
        )}
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        <VariantsOptionsBuilder
          selected={selected}
          onChange={handleOptionsChange}
          extraOptionTypes={typeOptionTypes}
        />

        {orphanedKeys.length > 0 && (
          <div className="rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm dark:border-amber-700 dark:bg-amber-950/40">
            <p className="font-medium text-amber-900 dark:text-amber-100">
              {t('admin.products.variants.orphan_warning', { count: orphanedKeys.length })}
            </p>
            {orphanedEntries.length > 0 && (
              <ul className="mt-1 list-disc pl-5 text-amber-900 dark:text-amber-200">
                {orphanedEntries.map((entry) => (
                  <li key={entry.key}>{entry.label}</li>
                ))}
              </ul>
            )}
            <div className="mt-2 flex items-center justify-end gap-2">
              <Button type="button" variant="ghost" size="sm" onClick={handleKeepOrphans}>
                {t('admin.products.variants.keep')}
              </Button>
              <Button
                type="button"
                variant="destructive"
                size="sm"
                onClick={handleConfirmDropOrphans}
              >
                {t('admin.actions.remove')}
              </Button>
            </div>
          </div>
        )}

        {fields.length > 0 && !awaitingOptionValues && (
          <div className="overflow-hidden rounded-md border border-border">
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              onDragEnd={handleDragEnd}
            >
              <SortableContext
                items={fields.map((f) => f._key)}
                strategy={verticalListSortingStrategy}
              >
                <Table>
                  <TableHeader>
                    <TableRow>
                      {!isSimpleProduct && (
                        <TableHead className="w-8" aria-label={t('admin.a11y.reorder')} />
                      )}
                      <TableHead>
                        {isSimpleProduct
                          ? t('admin.products.variants.default_variant')
                          : t('admin.products.variants.variant_label')}
                      </TableHead>
                      <TableHead>{t('admin.fields.variant.sku.label')}</TableHead>
                      <TableHead className="w-24" aria-label={t('admin.actions.actions_menu')} />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {fields.map((field, index) => (
                      <SortableVariantRow
                        key={field._key}
                        sortableId={field._key}
                        form={form}
                        index={index}
                        isSimpleProduct={isSimpleProduct}
                        optionTypes={allOptionTypes}
                        onEdit={() => handleEditRow(index)}
                        onRemove={() => handleRowRemove(index)}
                      />
                    ))}
                  </TableBody>
                </Table>
              </SortableContext>
            </DndContext>
          </div>
        )}
      </CardContent>

      <BulkVariantsDialog form={form} open={bulkOpen} onOpenChange={setBulkOpen} />

      {editingIndex !== null && (
        <VariantEditSheet
          form={form}
          variantIndex={editingIndex}
          open={sheetOpen}
          onOpenChange={(o) => {
            setSheetOpen(o)
            if (!o) setEditingIndex(null)
          }}
        />
      )}
    </Card>
  )
}

interface SortableVariantRowProps {
  sortableId: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  index: number
  isSimpleProduct: boolean
  optionTypes: OptionType[]
  onEdit: () => void
  onRemove: () => void
}

function SortableVariantRow({
  sortableId,
  form,
  index,
  isSimpleProduct,
  optionTypes,
  onEdit,
  onRemove,
}: SortableVariantRowProps) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: sortableId,
  })
  const style: CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  const variant = form.watch(`variants.${index}`)
  if (!variant) return null

  const label = variantDisplayLabel(
    variant,
    t('admin.products.variants.default_variant'),
    optionTypes,
  )

  return (
    <TableRow
      ref={setNodeRef}
      style={style}
      className={cn(isDragging && 'relative z-10 bg-card opacity-80 shadow-lg')}
    >
      {!isSimpleProduct && (
        <TableCell className="w-8 touch-none p-0">
          <DragHandle attributes={attributes} listeners={listeners} />
        </TableCell>
      )}
      <TableCell className="font-medium">{label}</TableCell>
      <TableCell>
        <Input
          aria-label={t('admin.fields.variant.sku.label')}
          placeholder={t('admin.fields.variant.sku.placeholder')}
          {...form.register(`variants.${index}.sku`)}
        />
      </TableCell>
      <TableCell className="text-right">
        <div className="flex items-center justify-end gap-1">
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            aria-label={t('admin.products.variants.edit_row_aria', { name: label })}
            onClick={onEdit}
          >
            <PencilIcon />
          </Button>
          {!isSimpleProduct && (
            <Button
              type="button"
              variant="ghost"
              size="icon-sm"
              aria-label={t('admin.products.variants.remove_row_aria', { name: label })}
              onClick={onRemove}
            >
              <XIcon />
            </Button>
          )}
        </div>
      </TableCell>
    </TableRow>
  )
}
