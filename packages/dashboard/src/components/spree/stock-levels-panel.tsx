import type { StockLevel } from '@spree/admin-sdk'
import {
  Button,
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
  Input,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import { ChevronDownIcon, ChevronRightIcon } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useStockLevels, useUpdateStockLevel } from '../../hooks/use-stock-levels'

/**
 * On-hand counts at one location, edited inline.
 *
 * Lives in the operator's dashboard rather than beside the rest of the
 * stock-locations page, which moved to `@spree/dashboard-core` so both panels
 * share it. This part could not follow: it reads the Admin API's stock levels
 * and links to the operator's own product route, neither of which a seller's
 * panel has. The shared page takes it as a slot instead, so the operator gets
 * this panel and a seller simply gets a page without it.
 */

export function StockLevelsPanel({ stockLocationId }: { stockLocationId: string }) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const { data, isFetching } = useStockLevels({
    stock_location_id_eq: stockLocationId,
    variant_sku_or_variant_product_name_cont: search.length >= 2 ? search : undefined,
    page,
    limit: 25,
  })
  const items = data?.data ?? []
  const totalPages = data?.meta?.pages ?? 1

  // Group by product so multi-variant products read as one card with sub-rows
  // instead of as N unrelated rows. Sort: low stock first, then product name.
  const groups = useMemo(
    () => groupItemsByProduct(items, t('admin.stock_locations.stock_levels.unknown_product')),
    [items, t],
  )

  return (
    <div className="rounded-md border">
      <div className="flex items-center justify-between gap-2 border-b px-4 py-3">
        <div>
          <h3 className="text-sm font-medium">{t('admin.stock_locations.stock_levels.title')}</h3>
          <p className="text-xs text-muted-foreground">
            {t('admin.stock_locations.stock_levels.help')}
          </p>
        </div>
        <Input
          placeholder={t('admin.stock_locations.stock_levels.search_placeholder')}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(1)
          }}
          className="h-8 w-56"
        />
      </div>
      {isFetching && items.length === 0 ? (
        <div className="px-4 py-6 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
      ) : items.length === 0 ? (
        <div className="px-4 py-6 text-sm text-muted-foreground">
          {search
            ? t('admin.stock_locations.stock_levels.empty_search')
            : t('admin.stock_locations.stock_levels.empty')}
        </div>
      ) : (
        <div className="divide-y">
          {groups.map((group) => (
            <ProductGroup key={group.productId} group={group} defaultOpen={groups.length <= 5} />
          ))}
        </div>
      )}
      {totalPages > 1 && (
        <div className="flex items-center justify-between border-t px-4 py-2">
          <span className="text-xs text-muted-foreground">
            {t('admin.common.page_of', { page, total: totalPages })}
          </span>
          <div className="flex gap-1">
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1 || isFetching}
            >
              {t('admin.common.prev')}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages || isFetching}
            >
              {t('admin.common.next')}
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}

interface StockLevelGroup {
  productId: string
  productName: string
  items: StockLevel[]
  hasLowStock: boolean
}

const LOW_STOCK_THRESHOLD = 5

function groupItemsByProduct(items: StockLevel[], unknownProductLabel: string): StockLevelGroup[] {
  const map = new Map<string, StockLevelGroup>()
  for (const item of items) {
    const productId = item.variant?.product_id ?? '__unknown__'
    const productName = item.variant?.product_name ?? unknownProductLabel
    let group = map.get(productId)
    if (!group) {
      group = { productId, productName, items: [], hasLowStock: false }
      map.set(productId, group)
    }
    group.items.push(item)
    if (item.count_on_hand < LOW_STOCK_THRESHOLD && !item.backorderable) {
      group.hasLowStock = true
    }
  }
  const groups = Array.from(map.values())
  groups.sort((a, b) => {
    if (a.hasLowStock !== b.hasLowStock) return a.hasLowStock ? -1 : 1
    return a.productName.localeCompare(b.productName)
  })
  return groups
}

function ProductGroup({ group, defaultOpen }: { group: StockLevelGroup; defaultOpen: boolean }) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(defaultOpen)

  return (
    <Collapsible open={open} onOpenChange={setOpen}>
      <CollapsibleTrigger className="flex w-full items-center gap-2 px-4 py-2 text-left hover:bg-accent">
        {open ? (
          <ChevronDownIcon className="size-4 text-muted-foreground" />
        ) : (
          <ChevronRightIcon className="size-4 text-muted-foreground" />
        )}
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-medium">{group.productName}</div>
          <div className="truncate text-xs text-muted-foreground">
            {t('admin.stock_locations.stock_levels.variant_count', { count: group.items.length })}
            {group.hasLowStock && ` · ${t('admin.stock_locations.stock_levels.low_stock_marker')}`}
          </div>
        </div>
      </CollapsibleTrigger>
      <CollapsibleContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.stock_locations.stock_levels.table.variant')}</TableHead>
              <TableHead className="text-right">
                {t('admin.stock_locations.stock_levels.table.on_hand')}
              </TableHead>
              <TableHead>{t('admin.stock_locations.stock_levels.table.backorder')}</TableHead>
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {group.items.map((item) => (
              <StockLevelRow key={item.id} item={item} />
            ))}
          </TableBody>
        </Table>
      </CollapsibleContent>
    </Collapsible>
  )
}

function StockLevelRow({ item }: { item: StockLevel }) {
  const { t } = useTranslation()
  const { storeId } = useParams({ from: '/_authenticated/$storeId' })
  const updateMutation = useUpdateStockLevel(item.id)
  const [count, setCount] = useState<number>(item.count_on_hand)
  const [backorderable, setBackorderable] = useState<boolean>(item.backorderable)

  useEffect(() => {
    setCount(item.count_on_hand)
    setBackorderable(item.backorderable)
  }, [item.count_on_hand, item.backorderable])

  const dirty = count !== item.count_on_hand || backorderable !== item.backorderable
  const variant = item.variant
  const optionsText = variant?.options_text
  const sku = variant?.sku
  const productId = variant?.product_id
  const variantLabel = optionsText || sku || t('admin.common.default')
  const isLowStock = count < LOW_STOCK_THRESHOLD && !backorderable

  function save() {
    if (!dirty) return
    updateMutation.mutate({
      count_on_hand: count,
      backorderable,
    })
  }

  return (
    <TableRow>
      <TableCell>
        <div className="min-w-0">
          {productId ? (
            <Link
              to="/$storeId/products/$productId"
              params={{ storeId, productId }}
              className="text-sm font-medium hover:underline"
            >
              {variantLabel}
            </Link>
          ) : (
            <span className="text-sm font-medium">{variantLabel}</span>
          )}
          {sku && <div className="text-xs text-muted-foreground">SKU {sku}</div>}
        </div>
      </TableCell>
      <TableCell className="text-right">
        <Input
          type="number"
          value={count}
          onChange={(e) => setCount(Number(e.target.value))}
          className={`ml-auto w-20 text-right ${isLowStock ? 'border-amber-500' : ''}`}
          aria-label={`On hand for ${variantLabel}`}
        />
      </TableCell>
      <TableCell>
        <Switch
          checked={backorderable}
          onCheckedChange={setBackorderable}
          aria-label={`Backorderable for ${variantLabel}`}
        />
      </TableCell>
      <TableCell className="text-right">
        <Button
          type="button"
          size="sm"
          variant="outline"
          onClick={save}
          disabled={!dirty || updateMutation.isPending}
        >
          {updateMutation.isPending ? '…' : t('admin.actions.save')}
        </Button>
      </TableCell>
    </TableRow>
  )
}
