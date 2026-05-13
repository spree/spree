import type { StockTransfer, Variant } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { ArrowLeftRightIcon, PlusIcon, TrashIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { RelativeTime } from '@/components/spree/relative-time'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { useStockLocations } from '@/hooks/use-stock-locations'
import {
  useCreateStockTransfer,
  useDeleteStockTransfer,
  useStockTransfer,
} from '@/hooks/use-stock-transfers'
import { formatPrice } from '@/lib/formatters'
import { Subject } from '@/lib/permissions'
import '@/tables/stock-transfers'
import { StockPageTabs } from './-tabs'

const stockTransfersSearchSchema = resourceSearchSchema.extend({
  view: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/products/stock/transfers')({
  validateSearch: stockTransfersSearchSchema,
  component: StockTransfersPage,
})

const SOURCE_NONE = '__external__'

function StockTransfersPage() {
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof stockTransfersSearchSchema>
  const navigate = useNavigate()

  const viewId = search.view
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { view: _v, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openView = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, view: id }) as never })

  useRowClickBridge('data-stock-transfer-id', openView)

  return (
    <>
      <StockPageTabs storeId={storeId} />
      <ResourceTable<StockTransfer>
        tableKey="stock-transfers"
        queryKey="stock-transfers"
        queryFn={(params) => adminClient.stockTransfers.list(params)}
        searchParams={search}
        actions={
          <Can I="create" a={Subject.StockTransfer}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              New transfer
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateStockTransferSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {viewId && (
        <ViewStockTransferSheet id={viewId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

interface PendingItem {
  variant: Variant
  quantity: number
}

function CreateStockTransferSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const createMutation = useCreateStockTransfer()
  const { data: stockLocations } = useStockLocations({ limit: 100 })
  const locations = stockLocations?.data ?? []

  const [sourceId, setSourceId] = useState<string>(SOURCE_NONE)
  const [destinationId, setDestinationId] = useState<string>('')
  const [reference, setReference] = useState('')
  const [items, setItems] = useState<PendingItem[]>([])
  const [variantSearch, setVariantSearch] = useState('')

  const { data: variantsData } = useQuery({
    queryKey: ['variants', 'search', variantSearch],
    queryFn: () => adminClient.variants.list({ search: variantSearch, limit: 8 }),
    enabled: variantSearch.length >= 3,
    staleTime: 30_000,
  })
  const variantResults = variantsData?.data ?? []

  const isExternalReceive = sourceId === SOURCE_NONE
  const canSubmit =
    !!destinationId &&
    items.length > 0 &&
    items.every((i) => i.quantity > 0) &&
    (isExternalReceive || sourceId !== destinationId)

  function reset() {
    setSourceId(SOURCE_NONE)
    setDestinationId('')
    setReference('')
    setItems([])
    setVariantSearch('')
  }

  function addItem(variant: Variant) {
    const existing = items.find((i) => i.variant.id === variant.id)
    if (existing) {
      setItems(
        items.map((i) => (i.variant.id === variant.id ? { ...i, quantity: i.quantity + 1 } : i)),
      )
    } else {
      setItems([...items, { variant, quantity: 1 }])
    }
    setVariantSearch('')
  }

  function updateQuantity(variantId: string, quantity: number) {
    setItems(items.map((i) => (i.variant.id === variantId ? { ...i, quantity } : i)))
  }

  function removeItem(variantId: string) {
    setItems(items.filter((i) => i.variant.id !== variantId))
  }

  async function handleSubmit() {
    if (!canSubmit) return
    await createMutation.mutateAsync({
      source_location_id: isExternalReceive ? undefined : sourceId,
      destination_location_id: destinationId,
      reference: reference.length > 0 ? reference : undefined,
      variants: items.map((i) => ({ variant_id: i.variant.id, quantity: i.quantity })),
    })
    reset()
    onOpenChange(false)
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) reset()
        onOpenChange(next)
      }}
    >
      <SheetContent className="sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>New stock transfer</SheetTitle>
          <SheetDescription>
            Move stock between locations, or omit a source to record an external receive.
          </SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="source">Source</FieldLabel>
              <Select value={sourceId} onValueChange={setSourceId}>
                <SelectTrigger id="source">
                  <SelectValue>
                    {(value) =>
                      value === SOURCE_NONE
                        ? 'External (vendor receive)'
                        : (locations.find((l) => l.id === value)?.name ?? (value as string))
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={SOURCE_NONE}>External (vendor receive)</SelectItem>
                  {locations.map((l) => (
                    <SelectItem key={l.id} value={l.id}>
                      {l.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel htmlFor="destination">Destination</FieldLabel>
              <Select value={destinationId} onValueChange={setDestinationId}>
                <SelectTrigger id="destination">
                  <SelectValue placeholder="Select destination location">
                    {(value) => locations.find((l) => l.id === value)?.name ?? (value as string)}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {locations
                    .filter((l) => l.id !== sourceId)
                    .map((l) => (
                      <SelectItem key={l.id} value={l.id}>
                        {l.name}
                      </SelectItem>
                    ))}
                </SelectContent>
              </Select>
              {sourceId !== SOURCE_NONE && sourceId === destinationId && (
                <p className="text-sm text-destructive">Source and destination must differ.</p>
              )}
            </Field>

            <Field>
              <FieldLabel htmlFor="reference">Reference (optional)</FieldLabel>
              <Input
                id="reference"
                placeholder="Vendor PO, invoice, or internal note"
                value={reference}
                onChange={(e) => setReference(e.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel>Variants</FieldLabel>
              <Input
                placeholder="Search by name or SKU (3+ chars)…"
                value={variantSearch}
                onChange={(e) => setVariantSearch(e.target.value)}
              />
              {variantSearch.length >= 3 && variantResults.length > 0 && (
                <div className="mt-1 rounded-lg border border-border bg-popover text-popover-foreground shadow-xs max-h-[280px] overflow-y-auto">
                  {variantResults.map((v) => (
                    <button
                      key={v.id}
                      type="button"
                      onClick={() => addItem(v)}
                      className="block w-full px-3 py-2.5 text-left text-sm hover:bg-muted transition-colors border-b last:border-0"
                    >
                      <div className="font-medium">{v.product_name ?? v.sku ?? v.id}</div>
                      <div className="text-xs text-muted-foreground">
                        SKU {v.sku} · {formatPrice(v.price)}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </Field>
          </FieldGroup>

          {items.length > 0 && (
            <div className="overflow-x-auto rounded-md border">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b bg-muted/50 text-muted-foreground">
                    <th className="p-3 pl-5 text-left font-normal">Variant</th>
                    <th className="p-3 text-left font-normal">SKU</th>
                    <th className="p-3 text-right font-normal">Qty</th>
                    <th className="p-3 pr-5 w-10" />
                  </tr>
                </thead>
                <tbody>
                  {items.map(({ variant, quantity }) => (
                    <tr key={variant.id} className="border-b last:border-b-0">
                      <td className="p-3 pl-5 font-medium">
                        {variant.product_name ?? variant.sku ?? variant.id}
                      </td>
                      <td className="p-3 text-muted-foreground">{variant.sku}</td>
                      <td className="p-3 text-right">
                        <Input
                          type="number"
                          min={1}
                          value={quantity}
                          onChange={(e) => updateQuantity(variant.id, Number(e.target.value))}
                          className="w-20 text-right ml-auto"
                        />
                      </td>
                      <td className="p-3 pr-5 text-right">
                        <Button
                          type="button"
                          size="icon-xs"
                          variant="ghost"
                          onClick={() => removeItem(variant.id)}
                        >
                          <TrashIcon className="size-4" />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
        <SheetFooter>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onOpenChange(false)}
            disabled={createMutation.isPending}
          >
            Cancel
          </Button>
          <Button
            type="button"
            size="sm"
            onClick={handleSubmit}
            disabled={!canSubmit || createMutation.isPending}
          >
            {createMutation.isPending ? 'Recording…' : 'Record transfer'}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

function ViewStockTransferSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { data: transfer, isLoading } = useStockTransfer(id)
  const deleteMutation = useDeleteStockTransfer()
  const confirm = useConfirm()
  const { data: stockLocations } = useStockLocations({ limit: 100 })

  const locationsById = useMemo(() => {
    const map = new Map<string, string>()
    for (const l of stockLocations?.data ?? []) {
      map.set(l.id, l.name)
    }
    return map
  }, [stockLocations])

  async function onDelete() {
    const ok = await confirm({
      title: 'Delete stock transfer?',
      message:
        'Deleting a transfer reverses the stock movements. Use with caution — this is mostly for fixing erroneous entries.',
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
  }

  const sourceName = transfer?.source_location_id
    ? (locationsById.get(transfer.source_location_id) ?? transfer.source_location_id)
    : null
  const destinationName = transfer?.destination_location_id
    ? (locationsById.get(transfer.destination_location_id) ?? transfer.destination_location_id)
    : null

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>{transfer ? `Transfer ${transfer.number}` : 'Stock transfer'}</SheetTitle>
          <SheetDescription>
            {transfer?.source_location_id ? (
              <>
                Inventory moved from <span className="font-medium">{sourceName}</span> to{' '}
                <span className="font-medium">{destinationName}</span>.
              </>
            ) : (
              <>
                External receive into <span className="font-medium">{destinationName}</span>.
              </>
            )}
          </SheetDescription>
        </SheetHeader>

        {isLoading || !transfer ? (
          <div className="p-4 text-sm text-muted-foreground">Loading…</div>
        ) : (
          <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
            <Card>
              <CardHeader>
                <CardTitle>Details</CardTitle>
              </CardHeader>
              <CardContent>
                <dl className="grid grid-cols-3 gap-y-2 text-sm">
                  <dt className="text-muted-foreground">Type</dt>
                  <dd className="col-span-2">
                    {transfer.source_location_id ? (
                      <Badge variant="outline">
                        <ArrowLeftRightIcon className="size-3" /> Internal
                      </Badge>
                    ) : (
                      <Badge variant="outline">External receive</Badge>
                    )}
                  </dd>

                  {transfer.reference && (
                    <>
                      <dt className="text-muted-foreground">Reference</dt>
                      <dd className="col-span-2">{transfer.reference}</dd>
                    </>
                  )}

                  <dt className="text-muted-foreground">Created</dt>
                  <dd className="col-span-2">
                    <RelativeTime iso={transfer.created_at} />
                  </dd>
                </dl>
              </CardContent>
            </Card>

            <p className="text-xs text-muted-foreground">
              Stock transfers are immutable once recorded. Deleting the transfer reverses its stock
              movements.
            </p>
          </div>
        )}

        <SheetFooter>
          <Can I="destroy" a={Subject.StockTransfer}>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={onDelete}
              disabled={deleteMutation.isPending}
              className="mr-auto text-destructive hover:bg-destructive/10 hover:text-destructive"
            >
              Delete
            </Button>
          </Can>
          <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Close
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
