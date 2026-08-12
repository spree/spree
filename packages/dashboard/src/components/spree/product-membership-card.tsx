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
import type { PaginationMeta, Product } from '@spree/admin-sdk'
import { adminClient, ResourcePickerSheet } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Checkbox,
  cn,
  DragHandle,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  Pagination,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Thumbnail,
  useConfirm,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { PlusIcon, SearchIcon, Trash2Icon, XIcon } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * The five mutations/queries a grouping needs to own its product membership.
 * `use-categories` and `use-collections` both expose exactly this shape, which
 * is what lets one card serve both.
 */
export interface ProductMembershipHooks {
  useProducts: (
    parentId: string | undefined,
    page?: number,
  ) => { data?: { data: Product[]; meta: PaginationMeta }; isLoading: boolean }
  useAdd: (parentId: string) => { mutateAsync: (productIds: string[]) => Promise<unknown> }
  useRemoveOne: (parentId: string) => { mutate: (productId: string) => void }
  useRemoveMany: (parentId: string) => {
    mutateAsync: (productIds: string[]) => Promise<unknown>
    isPending: boolean
  }
  useReposition: (parentId: string) => {
    mutate: (
      vars: { productId: string; new_position: number },
      opts?: { onError?: () => void },
    ) => void
  }
}

/**
 * Product membership for a category or collection: add via the picker sheet,
 * select rows to bulk-remove, remove a single row inline, drag to reorder,
 * click a product to open its detail page.
 *
 * Every write persists immediately — this panel is not part of the surrounding
 * form's save cycle — so both removals confirm first, and the confirm copy says
 * the change is immediate.
 *
 * Pass `readOnly` when membership is derived rather than curated (an automatic
 * collection materializes its members from rules): the list still renders, but
 * the checkboxes, drag handles, remove buttons and picker all disappear.
 */
export function ProductMembershipCard({
  parentId,
  storeId,
  hooks,
  translationNamespace,
  readOnly = false,
  description,
}: {
  parentId: string
  storeId: string
  hooks: ProductMembershipHooks
  /** Locale namespace holding the `products.*` copy, e.g. `admin.collections`. */
  translationNamespace: string
  readOnly?: boolean
  /** Rendered under the title — used to explain a read-only list. */
  description?: string
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const tr = (key: string, options?: Record<string, unknown>) =>
    t(`${translationNamespace}.products.${key}`, options ?? {})

  const [page, setPage] = useState(1)
  const { data, isLoading } = hooks.useProducts(parentId, page)
  const meta = data?.meta
  const addProducts = hooks.useAdd(parentId)
  const removeProduct = hooks.useRemoveOne(parentId)
  const removeProducts = hooks.useRemoveMany(parentId)
  const reposition = hooks.useReposition(parentId)

  const [pickerOpen, setPickerOpen] = useState(false)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [query, setQuery] = useState('')

  // Local order mirrors the server page so a drag re-renders instantly; the
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

  // Client-side quick filter over the current page. While a filter is active,
  // drag-reorder is disabled — reordering a filtered subset would compute
  // positions against the wrong neighbours.
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
      // `to` is an index within the current page; the endpoint wants a 0-based
      // index across the whole grouping. `meta.from` is 1-based.
      { productId: String(active.id), new_position: (meta?.from ?? 1) - 1 + to },
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

  // Both removals fire straight from a click with no sheet to review, so each
  // confirms first.
  async function handleBulkRemove() {
    const ids = [...selected]
    if (ids.length === 0) return

    const ok = await confirm({
      title: tr('remove_confirm.title'),
      message: tr('remove_confirm.message', { count: ids.length }),
      confirmLabel: t('admin.actions.remove'),
      variant: 'destructive',
    })
    if (!ok) return

    try {
      await removeProducts.mutateAsync(ids)
      setSelected(new Set())
    } catch {
      // The mutation toasts its own error; swallow the rethrow so the click
      // handler doesn't reject, and keep the selection so the user can retry.
    }
  }

  async function handleRemoveOne(product: Product) {
    const ok = await confirm({
      title: tr('remove_confirm.title'),
      message: tr('remove_confirm.message_named', { name: product.name ?? '' }),
      confirmLabel: t('admin.actions.remove'),
      variant: 'destructive',
    })
    if (!ok) return

    removeProduct.mutate(product.id)
  }

  const allSelected = visibleIds.length > 0 && visibleIds.every((id) => selected.has(id))
  const hasSelection = selected.size > 0
  const curatable = !readOnly

  return (
    <Card className="overflow-hidden">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>
            {tr('title')}
            {(meta?.count ?? 0) > 0 && (
              <span className="ml-2 font-normal text-muted-foreground text-sm">{meta?.count}</span>
            )}
          </CardTitle>
          {description && <CardDescription>{description}</CardDescription>}
        </div>
        {curatable &&
          (hasSelection ? (
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="text-destructive hover:text-destructive"
              onClick={handleBulkRemove}
              disabled={removeProducts.isPending}
            >
              <Trash2Icon className="size-4" />
              {tr('remove_selected', { count: selected.size })}
            </Button>
          ) : (
            <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
              <PlusIcon className="size-4" />
              {tr('add_cta')}
            </Button>
          ))}
      </CardHeader>
      <CardContent className="p-0">
        {isLoading ? (
          <p className="p-6 text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        ) : order.length === 0 ? (
          <p className="p-6 text-muted-foreground text-sm">
            {/* `empty_automatic` only exists for groupings that can be readOnly. */}
            {tr(readOnly ? 'empty_automatic' : 'empty')}
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
                  placeholder={tr('filter_placeholder')}
                />
              </InputGroup>
            </div>
            {visible.length === 0 ? (
              <p className="p-6 text-muted-foreground text-sm">{tr('no_matches')}</p>
            ) : (
              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleDragEnd}
              >
                <Table>
                  <TableHeader>
                    <TableRow>
                      {curatable && (
                        <TableHead className="w-10">
                          <Checkbox
                            checked={allSelected}
                            onCheckedChange={toggleAll}
                            aria-label={tr('select_all')}
                          />
                        </TableHead>
                      )}
                      <TableHead className="w-8" />
                      <TableHead>{tr('column_product')}</TableHead>
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
                          curatable={curatable}
                          // Reorder only makes sense over the full page; disable
                          // the drag handle while a filter narrows the rows.
                          reorderable={curatable && !filtering}
                          selected={selected.has(product.id)}
                          onToggleSelected={() => toggleSelected(product.id)}
                          onRemove={() => handleRemoveOne(product)}
                          removeLabel={tr('remove')}
                          selectRowLabel={tr('select_row')}
                        />
                      ))}
                    </TableBody>
                  </SortableContext>
                </Table>
              </DndContext>
            )}
            {/* Pagination brings its own top border + padding. */}
            {meta && <Pagination meta={meta} onPageChange={setPage} />}
          </>
        )}
      </CardContent>

      {curatable && (
        <ResourcePickerSheet<Product>
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          queryKey={`${translationNamespace}-${parentId}-products`}
          selectedIds={ids}
          onConfirm={async (picked) => {
            await addProducts.mutateAsync(picked)
          }}
          search={(q) => adminClient.products.list({ name_cont: q, limit: 25, sort: 'name' })}
          getOptionLabel={(p) => p.name ?? p.id}
          getOptionImageUrl={(p) => p.thumbnail_url}
          getOptionSubtitle={(p) => p.slug ?? null}
          title={tr('picker_title')}
          description={tr('picker_description')}
          searchPlaceholder={tr('search_placeholder')}
        />
      )}
    </Card>
  )
}

function ProductRow({
  product,
  storeId,
  curatable,
  reorderable,
  selected,
  onToggleSelected,
  onRemove,
  removeLabel,
  selectRowLabel,
}: {
  product: Product
  storeId: string
  curatable: boolean
  reorderable: boolean
  selected: boolean
  onToggleSelected: () => void
  onRemove: () => void
  removeLabel: string
  selectRowLabel: string
}) {
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
      {curatable && (
        <TableCell>
          <Checkbox
            checked={selected}
            onCheckedChange={onToggleSelected}
            aria-label={selectRowLabel}
          />
        </TableCell>
      )}
      <TableCell className="pr-0">
        {reorderable && <DragHandle attributes={attributes} listeners={listeners} />}
      </TableCell>
      <TableCell>
        <Link
          to="/$storeId/products/$productId"
          params={{ storeId, productId: product.id }}
          className="flex items-center gap-3 hover:underline"
        >
          <Thumbnail src={product.thumbnail_url} size="sm" />
          <span className="truncate text-sm">{product.name}</span>
        </Link>
      </TableCell>
      <TableCell className="text-right">
        {curatable && (
          <Button
            type="button"
            variant="ghost"
            size="icon"
            onClick={onRemove}
            aria-label={removeLabel}
          >
            <XIcon className="size-4" />
          </Button>
        )}
      </TableCell>
    </tr>
  )
}
