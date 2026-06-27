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
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { Product } from '@spree/admin-sdk'
import { adminClient, ResourcePickerSheet } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  cn,
  DragHandle,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import { ImageIcon, PlusIcon, SearchIcon, Trash2Icon, XIcon } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useAddCategoryProducts,
  useCategoryProducts,
  useRemoveCategoryProduct,
  useRemoveCategoryProducts,
  useRepositionCategoryProduct,
} from '@/hooks/use-categories'

/**
 * Manual product membership + ordering for a category — the SPA equivalent of
 * the old Rails admin taxon "Products" panel. Add via the universal picker
 * sheet, select rows to bulk-remove, remove a single row inline, drag to
 * reorder, click a product to open its detail page. Only rendered for a
 * persisted category (needs an id to mutate).
 */
export function CategoryProductsCard({ categoryId }: { categoryId: string }) {
  const { t } = useTranslation()
  const { storeId } = useParams({
    from: '/_authenticated/$storeId/products/categories/$categoryId',
  })
  const { data, isLoading } = useCategoryProducts(categoryId)
  const addProducts = useAddCategoryProducts(categoryId)
  const removeProduct = useRemoveCategoryProduct(categoryId)
  const removeProducts = useRemoveCategoryProducts(categoryId)
  const reposition = useRepositionCategoryProduct(categoryId)

  const [pickerOpen, setPickerOpen] = useState(false)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [query, setQuery] = useState('')

  // Local order mirrors the server list so a drag re-renders instantly; the
  // reposition mutation invalidates and re-syncs.
  const [order, setOrder] = useState<Product[]>([])
  useEffect(() => {
    if (data?.data) setOrder(data.data)
  }, [data])

  // Drop stale selections when the underlying list changes (after a removal).
  useEffect(() => {
    setSelected((prev) => {
      const present = new Set(order.map((p) => p.id))
      const next = new Set([...prev].filter((id) => present.has(id)))
      return next.size === prev.size ? prev : next
    })
  }, [order])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const ids = useMemo(() => order.map((p) => p.id), [order])

  // Client-side quick filter over the assigned products. While a filter is
  // active, drag-reorder is disabled — reordering a filtered subset would
  // compute positions against the wrong neighbours.
  const trimmedQuery = query.trim().toLowerCase()
  const filtering = trimmedQuery.length > 0
  const visible = useMemo(
    () =>
      filtering ? order.filter((p) => (p.name ?? '').toLowerCase().includes(trimmedQuery)) : order,
    [order, filtering, trimmedQuery],
  )
  const visibleIds = useMemo(() => visible.map((p) => p.id), [visible])

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const from = order.findIndex((p) => p.id === active.id)
    const to = order.findIndex((p) => p.id === over.id)
    if (from === -1 || to === -1) return
    const previousOrder = order
    setOrder(arrayMove(order, from, to)) // optimistic
    reposition.mutate(
      { productId: String(active.id), new_position: to },
      { onError: () => setOrder(previousOrder) }, // roll back if the move fails
    )
  }

  function toggleSelected(id: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  // Operate only on the currently-visible (filtered) rows so "select all" never
  // pulls in hidden products that a later bulk-remove would delete unseen.
  function toggleAll() {
    setSelected((prev) => {
      if (visibleIds.length > 0 && visibleIds.every((id) => prev.has(id))) {
        const next = new Set(prev)
        for (const id of visibleIds) next.delete(id)
        return next
      }
      return new Set([...prev, ...visibleIds])
    })
  }

  async function handleBulkRemove() {
    const ids = [...selected]
    if (ids.length === 0) return
    await removeProducts.mutateAsync(ids)
    setSelected(new Set())
  }

  const allSelected = visibleIds.length > 0 && visibleIds.every((id) => selected.has(id))
  const hasSelection = selected.size > 0

  return (
    <Card className="overflow-hidden">
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>
          {t('admin.categories.products.title')}
          {order.length > 0 && (
            <span className="ml-2 font-normal text-muted-foreground text-sm">{order.length}</span>
          )}
        </CardTitle>
        {hasSelection ? (
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="text-destructive hover:text-destructive"
            onClick={handleBulkRemove}
            disabled={removeProducts.isPending}
          >
            <Trash2Icon className="size-4" />
            {t('admin.categories.products.remove_selected', { count: selected.size })}
          </Button>
        ) : (
          <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.categories.products.add_cta')}
          </Button>
        )}
      </CardHeader>
      <CardContent className="p-0">
        {isLoading ? (
          <p className="p-6 text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        ) : order.length === 0 ? (
          <p className="p-6 text-muted-foreground text-sm">
            {t('admin.categories.products.empty')}
          </p>
        ) : (
          <>
            <div className="border-border border-b p-3">
              <InputGroup>
                <InputGroupAddon>
                  <SearchIcon className="size-4 text-muted-foreground" />
                </InputGroupAddon>
                <InputGroupInput
                  type="search"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && e.preventDefault()}
                  placeholder={t('admin.categories.products.filter_placeholder')}
                />
              </InputGroup>
            </div>
            {visible.length === 0 ? (
              <p className="p-6 text-muted-foreground text-sm">
                {t('admin.categories.products.no_matches')}
              </p>
            ) : (
              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleDragEnd}
              >
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="w-10">
                        <Checkbox
                          checked={allSelected}
                          onCheckedChange={toggleAll}
                          aria-label={t('admin.categories.products.select_all')}
                        />
                      </TableHead>
                      <TableHead className="w-8" />
                      <TableHead>{t('admin.categories.products.column_product')}</TableHead>
                      <TableHead className="w-10" />
                    </TableRow>
                  </TableHeader>
                  <SortableContext items={ids} strategy={verticalListSortingStrategy}>
                    <TableBody className="border-t border-border">
                      {visible.map((product) => (
                        <ProductRow
                          key={product.id}
                          product={product}
                          storeId={storeId}
                          // Reorder only makes sense over the full list; disable
                          // the drag handle while a filter narrows the rows.
                          reorderable={!filtering}
                          selected={selected.has(product.id)}
                          onToggleSelected={() => toggleSelected(product.id)}
                          onRemove={() => removeProduct.mutate(product.id)}
                        />
                      ))}
                    </TableBody>
                  </SortableContext>
                </Table>
              </DndContext>
            )}
          </>
        )}
      </CardContent>

      <ResourcePickerSheet<Product>
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        queryKey={`category-${categoryId}-products`}
        selectedIds={ids}
        onConfirm={async (picked) => {
          await addProducts.mutateAsync(picked)
        }}
        search={(q) => adminClient.products.list({ name_cont: q, limit: 25, sort: 'name' })}
        getOptionLabel={(p) => p.name ?? p.id}
        getOptionImageUrl={(p) => p.thumbnail_url}
        getOptionSubtitle={(p) => p.slug ?? null}
        title={t('admin.categories.products.picker_title')}
        description={t('admin.categories.products.picker_description')}
        searchPlaceholder={t('admin.categories.products.search_placeholder')}
      />
    </Card>
  )
}

function ProductRow({
  product,
  storeId,
  reorderable,
  selected,
  onToggleSelected,
  onRemove,
}: {
  product: Product
  storeId: string
  reorderable: boolean
  selected: boolean
  onToggleSelected: () => void
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: product.id,
    disabled: !reorderable,
  })

  return (
    <tr
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      // Mirror <TableRow> styling — a plain <tr> is required so dnd-kit's
      // setNodeRef attaches (TableRow doesn't forward refs).
      className={cn(
        'group/row last:*:border-b-0 hover:bg-muted/60',
        selected && 'bg-muted/40',
        isDragging && 'relative z-10 opacity-70',
      )}
    >
      <TableCell>
        <Checkbox
          checked={selected}
          onCheckedChange={onToggleSelected}
          aria-label={t('admin.categories.products.select_row')}
        />
      </TableCell>
      <TableCell className="pr-0">
        {reorderable && <DragHandle attributes={attributes} listeners={listeners} />}
      </TableCell>
      <TableCell>
        <Link
          to="/$storeId/products/$productId"
          params={{ storeId, productId: product.id }}
          className="flex items-center gap-3 hover:underline"
        >
          <span className="flex size-9 shrink-0 items-center justify-center overflow-hidden rounded border border-border bg-muted">
            {product.thumbnail_url ? (
              <img src={product.thumbnail_url} alt="" className="size-full object-cover" />
            ) : (
              <ImageIcon className="size-4 text-muted-foreground" />
            )}
          </span>
          <span className="truncate text-sm">{product.name}</span>
        </Link>
      </TableCell>
      <TableCell className="text-right">
        <Button
          type="button"
          variant="ghost"
          size="icon"
          onClick={onRemove}
          aria-label={t('admin.categories.products.remove')}
        >
          <XIcon className="size-4" />
        </Button>
      </TableCell>
    </tr>
  )
}
