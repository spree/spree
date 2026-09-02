import type { PaginationMeta, Product } from '@spree/admin-sdk'
import { adminClient, ResourcePickerSheet } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  ProductMembershipList,
  type ProductMembershipListProps,
  type ProductMembershipRow,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { type ReactNode, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useProductMembershipStaging } from './product-membership-staging'

/** The paginated members query — `useCatalogProducts`-shaped. */
export type ProductMembershipQuery = (
  parentId: string | undefined,
  page?: number,
) => { data?: { data: Product[]; meta: PaginationMeta }; isLoading: boolean }

/** Raw paginated membership fetch for picker exclusion across every list page. */
export type ProductMembershipListPage = (
  parentId: string,
  page: number,
) => Promise<{ data: Product[]; meta: PaginationMeta }>

/** Persists a drag-to-reorder. Resolve to commit, reject to roll back. */
export type ProductMembershipReorder = (productId: string, position: number) => Promise<unknown>

/**
 * Product membership for a parent that saves as a form — the one card every
 * curating parent uses: categories, collections, catalogs and price lists.
 *
 * Nothing here writes on click. The picker stages additions and the row "x"
 * stages removals into the surrounding form
 * (`ProductMembershipStagingProvider`), which makes the page dirty; the
 * page's Save flushes them through the parent's nested products endpoints
 * and its Discard rolls them back. Staged rows are badged or struck through
 * so the pending state stays visible, and a staged removal restores in one
 * click — so removals need no confirm, because Save is the confirmation.
 *
 * Pass `onReorder` for a parent whose membership carries a manual order
 * (categories and collections, whose position drives storefront display).
 * Reordering persists on drop rather than on Save — replaying a drag
 * sequence against server-side positions is not reliable — so it is
 * disabled while any membership change is staged.
 *
 * Pass `readOnly` where membership is derived rather than curated (an
 * automatic collection materializes its members from rules): the list still
 * renders, but every control disappears.
 */
export function DeferredProductMembershipCard({
  parentId,
  storeId,
  canEdit = true,
  readOnly = false,
  useProducts,
  listMembersPage,
  onReorder,
  translationNamespace,
  description,
  extraColumns,
  headerActions,
}: {
  parentId: string
  storeId: string
  /** False for a viewer without update permission on the parent. */
  canEdit?: boolean
  /** True when membership is rule-derived and cannot be curated at all. */
  readOnly?: boolean
  useProducts: ProductMembershipQuery
  /** When set, every persisted member id is excluded from the picker, not just the current list page. */
  listMembersPage?: ProductMembershipListPage
  onReorder?: ProductMembershipReorder
  /** Locale namespace holding the `products.*` copy, e.g. `admin.catalogs`. */
  translationNamespace: string
  /** Rendered under the title while nothing is staged. */
  description?: string
  /**
   * Extra per-row columns, for a parent whose membership carries data of its
   * own — a catalog's quantity terms, or what its agreement charges.
   *
   * A function receives the server rows this page loaded, for a column whose
   * value the listing itself carries rather than the form: the card owns that
   * query, so lifting it out only to read a column back would mean fetching
   * the same page twice.
   */
  extraColumns?:
    | ProductMembershipListProps['extraColumns']
    | ((products: Product[]) => ProductMembershipListProps['extraColumns'])
  /**
   * Extra controls beside Add products, for an action that belongs on these
   * rows rather than in a card of its own — pricing a catalog's assortment.
   * Hidden while a selection is active, since the header is then the bulk
   * remove.
   */
  headerActions?: ReactNode
}) {
  const { t } = useTranslation()
  const tr = (key: string, options?: Record<string, unknown>) =>
    t(`${translationNamespace}.products.${key}`, options ?? {})

  const staging = useProductMembershipStaging()
  const { adds: pendingAdds, removes: pendingRemoves } = staging

  const [page, setPage] = useState(1)
  const { data, isLoading } = useProducts(parentId, page)
  const meta = data?.meta
  const serverProducts = useMemo(() => data?.data ?? [], [data])

  const [pickerOpen, setPickerOpen] = useState(false)
  const [selected, setSelected] = useState<string[]>([])

  const { data: allPersistedMemberIds } = useQuery({
    queryKey: [translationNamespace, parentId, 'membership-picker-exclude-ids'],
    queryFn: async () => {
      if (!listMembersPage) return [] as string[]
      const ids: string[] = []
      let memberPage = 1
      while (true) {
        const response = await listMembersPage(parentId, memberPage)
        ids.push(...response.data.map((product) => product.id))
        const pages = response.meta?.pages ?? memberPage
        if (!response.meta?.next || memberPage >= pages) break
        memberPage += 1
      }
      return ids
    },
    enabled: pickerOpen && !!listMembersPage,
    staleTime: 30_000,
  })

  const persistedMemberIds = allPersistedMemberIds ?? serverProducts.map((product) => product.id)

  const pendingRemoveSet = useMemo(() => new Set(pendingRemoves), [pendingRemoves])
  const pendingAddIds = useMemo(() => new Set(pendingAdds.map((p) => p.id)), [pendingAdds])

  // Staged additions are pinned on top of every page so they stay visible.
  const rows = useMemo<ProductMembershipRow[]>(
    () => [
      ...pendingAdds.map((product) => ({
        id: product.id,
        name: product.name,
        thumbnailUrl: product.thumbnail_url,
        pending: 'added' as const,
      })),
      ...serverProducts.map((product) => ({
        id: product.id,
        name: product.name,
        thumbnailUrl: product.thumbnail_url,
        pending: pendingRemoveSet.has(product.id) ? ('removed' as const) : undefined,
      })),
    ],
    [pendingAdds, serverProducts, pendingRemoveSet],
  )

  // Drop stale selections when rows leave the list.
  useEffect(() => {
    const present = new Set(rows.filter((row) => row.pending !== 'removed').map((row) => row.id))
    setSelected((prev) => {
      const next = prev.filter((id) => present.has(id))
      return next.length === prev.length ? prev : next
    })
  }, [rows])

  function stageRemove(ids: string[]) {
    const removing = new Set(ids)
    const stagedAdds = ids.filter((id) => pendingAddIds.has(id))
    if (stagedAdds.length > 0) {
      // Removing a staged addition just unstages it.
      staging.setAdds(pendingAdds.filter((product) => !removing.has(product.id)))
    }
    const persisted = ids.filter((id) => !pendingAddIds.has(id) && !pendingRemoveSet.has(id))
    if (persisted.length > 0) {
      staging.setRemoves([...pendingRemoves, ...persisted])
    }
    setSelected((prev) => prev.filter((id) => !removing.has(id)))
  }

  function restore(id: string) {
    staging.setRemoves(pendingRemoves.filter((existing) => existing !== id))
  }

  const curatable = canEdit && !readOnly

  const pickerSelectedIds = useMemo(() => {
    const ids = new Set(pendingAdds.map((product) => product.id))
    for (const id of persistedMemberIds) {
      if (!pendingRemoveSet.has(id)) ids.add(id)
    }
    return Array.from(ids)
  }, [pendingAdds, persistedMemberIds, pendingRemoveSet])

  // Only the persisted total — staged rows are marked in the list itself, and
  // netting them into the count reads as wrong next to the visible rows.
  const count = meta?.count ?? 0

  return (
    <Card className="overflow-hidden">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>
            {tr('title')}
            {count > 0 && (
              <span className="ml-2 font-normal text-muted-foreground text-sm">{count}</span>
            )}
          </CardTitle>
          {/* A read-only list explains itself first: it cannot be curated, so
              its own description outranks any staging left over from before
              the parent was switched to rule-driven membership. */}
          {staging.dirty && curatable ? (
            <CardDescription>{tr('pending_changes_hint')}</CardDescription>
          ) : (
            description && <CardDescription>{description}</CardDescription>
          )}
        </div>
        {curatable &&
          (selected.length > 0 ? (
            <Button
              type="button"
              variant="destructive"
              size="sm"
              onClick={() => stageRemove(selected)}
            >
              <Trash2Icon className="size-4" />
              {tr('remove_selected', { count: selected.length })}
            </Button>
          ) : (
            <div className="flex items-center gap-2">
              {headerActions}
              <Button type="button" variant="outline" size="sm" onClick={() => setPickerOpen(true)}>
                <PlusIcon className="size-4" />
                {tr('add_cta')}
              </Button>
            </div>
          ))}
      </CardHeader>
      <CardContent className="p-0">
        <ProductMembershipList
          rows={rows}
          loading={isLoading}
          meta={meta}
          onPageChange={setPage}
          readOnly={!curatable}
          selected={selected}
          onSelectedChange={setSelected}
          onRemove={(id) => stageRemove([id])}
          onRestore={restore}
          // Reorder writes through on drop, so it would fight the staged
          // rows: positions are computed against a list that is about to
          // change. Disabled until the staged changes are saved.
          reorderable={Boolean(onReorder) && curatable && !staging.dirty}
          onReorder={onReorder}
          extraColumns={
            typeof extraColumns === 'function' ? extraColumns(serverProducts) : extraColumns
          }
          renderTitle={(row) => (
            <Link
              to="/$storeId/products/$productId"
              params={{ storeId, productId: row.id }}
              className="truncate text-sm hover:underline"
            >
              {row.name}
            </Link>
          )}
          labels={{
            filterPlaceholder: tr('filter_placeholder'),
            clearFilter: t('admin.common.clear'),
            noMatches: tr('no_matches'),
            // `empty_automatic` only exists for parents that can be readOnly.
            empty: tr(readOnly ? 'empty_automatic' : 'empty'),
            loading: t('admin.common.loading'),
            columnProduct: tr('column_product'),
            selectAll: tr('select_all'),
            selectRow: tr('select_row'),
            remove: tr('remove'),
            restore: tr('restore'),
            pendingAddedBadge: tr('pending_added_badge'),
          }}
        />
      </CardContent>

      {curatable && (
        <ResourcePickerSheet<Product>
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          queryKey={`${translationNamespace}-${parentId}-products-picker`}
          // Pending removals are excluded: the picker locks its `selectedIds`
          // as "already in, not re-addable", so leaving them in would grey out
          // a product the merchant just removed and leave the row's restore
          // arrow as the only way back.
          selectedIds={pickerSelectedIds}
          onConfirm={(_, records) => {
            // Re-picking a product staged for removal cancels that removal —
            // it is still a member, so staging it as an addition too would
            // render the row twice and then add it back after the delete.
            const picked = new Set(records.map((record) => record.id))
            if (pendingRemoves.some((id) => picked.has(id))) {
              staging.setRemoves(pendingRemoves.filter((id) => !picked.has(id)))
            }
            const fresh = records.filter(
              (record) => !pendingAddIds.has(record.id) && !pendingRemoveSet.has(record.id),
            )
            if (fresh.length > 0) staging.setAdds([...pendingAdds, ...fresh])
          }}
          search={(query, page) => {
            const excludeIds = pickerSelectedIds
            return adminClient.products.list({
              ...(query ? { name_cont: query } : {}),
              limit: 25,
              page,
              sort: 'name',
              ...(excludeIds.length > 0 ? { id_not_in: excludeIds } : {}),
            })
          }}
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
