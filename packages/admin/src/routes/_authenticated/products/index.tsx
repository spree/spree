import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useProducts } from '@/hooks/use-products'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { StatusBadge } from '@/components/ui/badge'
import { Pagination } from '@/components/ui/pagination'
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  TableEmpty,
} from '@/components/ui/data-table'
import {
  TableToolbar,
  type ColumnDef,
  type FilterRule,
  type SortOption,
} from '@/components/table-toolbar'
import { z } from 'zod/v4'
import { PlusIcon, PackageIcon } from 'lucide-react'
import { useState, useDeferredValue } from 'react'

// ============================================================================
// Column definitions — mirrors the Rails admin spree_admin_tables.rb config
// ============================================================================

const productColumns: ColumnDef[] = [
  {
    key: 'name',
    label: 'Name',
    sortable: true,
    filterable: true,
    default: true,
  },
  {
    key: 'status',
    label: 'Status',
    sortable: true,
    filterable: true,
    default: true,
    filterType: 'status',
    filterOptions: [
      { value: 'draft', label: 'Draft' },
      { value: 'active', label: 'Active' },
      { value: 'archived', label: 'Archived' },
    ],
  },
  {
    key: 'inventory',
    label: 'Inventory',
    sortable: false,
    filterable: false,
    default: true,
  },
  {
    key: 'price',
    label: 'Price',
    sortable: true,
    filterable: true,
    default: true,
    filterType: 'number',
  },
  {
    key: 'sku',
    label: 'SKU',
    sortable: false,
    filterable: true,
    default: false,
  },
  {
    key: 'created_at',
    label: 'Created at',
    sortable: true,
    filterable: true,
    default: false,
    filterType: 'date',
  },
  {
    key: 'updated_at',
    label: 'Updated at',
    sortable: true,
    filterable: true,
    default: false,
    filterType: 'date',
  },
]

const defaultColumns = productColumns.filter((c) => c.default).map((c) => c.key)

// ============================================================================
// Route
// ============================================================================

const filterSchema = z.object({
  id: z.string(),
  field: z.string(),
  operator: z.string(),
  value: z.string(),
})

const searchSchema = z.object({
  page: z.coerce.number().optional().default(1),
  sort: z.string().optional().default('updated_at'),
  dir: z.enum(['asc', 'desc']).optional().default('desc'),
  search: z.string().optional(),
  filters: z.preprocess(
    (val) => {
      if (typeof val === 'string') {
        try { return JSON.parse(val) } catch { return [] }
      }
      return val ?? []
    },
    z.array(filterSchema).optional().default([]),
  ),
  columns: z.preprocess(
    (val) => {
      if (typeof val === 'string') return val.split(',')
      return val ?? undefined
    },
    z.array(z.string()).optional(),
  ),
})

export const Route = createFileRoute('/_authenticated/products/')({
  validateSearch: searchSchema,
  component: ProductsPage,
})

// ============================================================================
// Page
// ============================================================================

function ProductsPage() {
  const { page, sort, dir, search, filters, columns: urlColumns } = Route.useSearch()
  const navigate = useNavigate({ from: Route.fullPath })

  const [searchInput, setSearchInput] = useState(search ?? '')
  const deferredSearch = useDeferredValue(searchInput)
  const visibleColumns = urlColumns ?? defaultColumns

  const sortString = dir === 'desc' ? `-${sort}` : sort

  const { data, isLoading } = useProducts({
    page,
    sort: sortString,
    search: deferredSearch || undefined,
    filters: filters as FilterRule[],
  })

  const products = data?.data ?? []
  const meta = data?.meta

  // Navigation helpers
  function updateSearch(updates: Record<string, unknown>) {
    navigate({ search: (prev) => ({ ...prev, ...updates }) })
  }

  function handleSearchChange(value: string) {
    setSearchInput(value)
    updateSearch({ search: value || undefined, page: 1 })
  }

  function handleSortChange(s: SortOption) {
    updateSearch({ sort: s.field, dir: s.direction, page: 1 })
  }

  function handleFiltersChange(f: FilterRule[]) {
    updateSearch({
      filters: f.length > 0 ? JSON.stringify(f) : undefined,
      page: 1,
    })
  }

  function handleColumnsChange(cols: string[]) {
    const isDefault = cols.length === defaultColumns.length && cols.every((c) => defaultColumns.includes(c))
    updateSearch({ columns: isDefault ? undefined : cols.join(',') })
  }

  const showSku = visibleColumns.includes('sku')
  const showCreatedAt = visibleColumns.includes('created_at')
  const showUpdatedAt = visibleColumns.includes('updated_at')

  const colCount = 2 + // name is always shown, price is always shown
    (visibleColumns.includes('status') ? 1 : 0) +
    (visibleColumns.includes('inventory') ? 1 : 0) +
    (showSku ? 1 : 0) +
    (showCreatedAt ? 1 : 0) +
    (showUpdatedAt ? 1 : 0)

  return (
    <Card className="rounded-2xl">
      <TableToolbar
        columns={productColumns}
        visibleColumns={visibleColumns}
        onVisibleColumnsChange={handleColumnsChange}
        search={searchInput}
        onSearchChange={handleSearchChange}
        searchPlaceholder="Search products..."
        sort={{ field: sort, direction: dir }}
        onSortChange={handleSortChange}
        filters={filters as FilterRule[]}
        onFiltersChange={handleFiltersChange}
        actions={
          <Button size="sm" className="h-[2.125rem]">
            <PlusIcon className="size-4" />
            Add Product
          </Button>
        }
      />
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <tr>
              <TableHead>Name</TableHead>
              {visibleColumns.includes('status') && <TableHead>Status</TableHead>}
              {visibleColumns.includes('inventory') && <TableHead>Inventory</TableHead>}
              {showSku && <TableHead>SKU</TableHead>}
              <TableHead className="text-right">Price</TableHead>
              {showCreatedAt && <TableHead>Created</TableHead>}
              {showUpdatedAt && <TableHead>Updated</TableHead>}
            </tr>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableEmpty colSpan={colCount}>Loading products...</TableEmpty>
            ) : products.length === 0 ? (
              <TableEmpty colSpan={colCount}>
                <div className="flex flex-col items-center gap-2">
                  <PackageIcon className="size-8 text-muted-foreground/50" />
                  <p>No products found</p>
                  {(deferredSearch || (filters as FilterRule[]).length > 0) && (
                    <p className="text-xs">
                      Try adjusting your search or filters
                    </p>
                  )}
                </div>
              </TableEmpty>
            ) : (
              products.map((product: any) => (
                <TableRow key={product.id}>
                  <TableCell>
                    <Link
                      to="/products/$productId"
                      params={{ productId: product.id }}
                      className="flex items-center gap-3 no-underline"
                    >
                      <div className="flex size-10 shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-gray-50 overflow-hidden">
                        {product.thumbnail_url ? (
                          <img
                            src={product.thumbnail_url}
                            alt={product.name}
                            className="size-full object-cover"
                          />
                        ) : (
                          <PackageIcon className="size-4 text-gray-400" />
                        )}
                      </div>
                      <div className="min-w-0">
                        <div className="truncate font-medium text-zinc-950">
                          {product.name}
                        </div>
                      </div>
                    </Link>
                  </TableCell>
                  {visibleColumns.includes('status') && (
                    <TableCell>
                      <StatusBadge status={product.status} />
                    </TableCell>
                  )}
                  {visibleColumns.includes('inventory') && (
                    <TableCell>
                      <InventoryCell product={product} />
                    </TableCell>
                  )}
                  {showSku && (
                    <TableCell className="text-sm text-muted-foreground">
                      {product.sku ?? '—'}
                    </TableCell>
                  )}
                  <TableCell className="text-right tabular-nums whitespace-nowrap">
                    {product.price ? formatPrice(product.price) : '—'}
                  </TableCell>
                  {showCreatedAt && (
                    <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
                      {formatRelativeTime(product.created_at)}
                    </TableCell>
                  )}
                  {showUpdatedAt && (
                    <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
                      {formatRelativeTime(product.updated_at)}
                    </TableCell>
                  )}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
        {meta && (
          <Pagination
            meta={meta}
            onPageChange={(p) => updateSearch({ page: p })}
          />
        )}
      </CardContent>
    </Card>
  )
}

// ============================================================================
// Helpers
// ============================================================================

function InventoryCell({ product }: { product: any }) {
  if (!product.in_stock && !product.backorderable) {
    return <span className="text-sm text-destructive">Out of stock</span>
  }
  if (product.backorderable && !product.in_stock) {
    return <span className="text-sm text-muted-foreground">On backorder</span>
  }
  return <span className="text-sm text-muted-foreground">In stock</span>
}

function formatPrice(price: { amount?: string; currency?: string; display?: string } | null) {
  if (!price) return '—'
  return price.display ?? `${price.currency} ${price.amount}`
}

function formatRelativeTime(iso: string) {
  const date = new Date(iso)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMins / 60)
  const diffDays = Math.floor(diffHours / 24)

  if (diffMins < 1) return 'just now'
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffHours < 24) return `${diffHours}h ago`
  if (diffDays < 30) return `${diffDays}d ago`

  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined })
}
