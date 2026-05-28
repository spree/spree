import type { StockTransfer, Variant } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  formatPrice,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  RelativeTime,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { ArrowLeftRightIcon, EyeIcon, PlusIcon, TrashIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Trans, useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useStockLocations } from '@/hooks/use-stock-locations'
import {
  useCreateStockTransfer,
  useDeleteStockTransfer,
  useStockTransfer,
} from '@/hooks/use-stock-transfers'
import '@/tables/stock-transfers'

const stockTransfersSearchSchema = resourceSearchSchema.extend({
  view: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/products/transfers')({
  validateSearch: stockTransfersSearchSchema,
  component: StockTransfersPage,
})

const SOURCE_NONE = '__external__'

function StockTransfersPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof stockTransfersSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteStockTransfer()
  const { permissions } = usePermissions()

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

  async function handleDelete(transfer: StockTransfer) {
    const ok = await confirm({
      title: t('admin.products.transfers.delete_confirm.title'),
      message: t('admin.products.transfers.delete_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(transfer.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<StockTransfer>
        tableKey="stock-transfers"
        queryKey="stock-transfers"
        queryFn={(params) => adminClient.stockTransfers.list(params)}
        searchParams={search}
        rowActions={(transfer) => (
          <RowActions
            actions={[
              {
                key: 'view',
                label: t('admin.actions.view_details'),
                icon: <EyeIcon className="size-4" />,
                onSelect: () => openView(transfer.id),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.StockTransfer),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(transfer),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.StockTransfer}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.products.transfers.new_cta')}
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
  const { t } = useTranslation()
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
          <SheetTitle>{t('admin.pages.products.transfers.sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.products.transfers.create_description')}</SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="source">
                {t('admin.pages.products.transfers.section_from')}
              </FieldLabel>
              <Select value={sourceId} onValueChange={setSourceId}>
                <SelectTrigger id="source">
                  <SelectValue>
                    {(value) =>
                      value === SOURCE_NONE
                        ? t('admin.products.transfers.external_label')
                        : (locations.find((l) => l.id === value)?.name ?? (value as string))
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={SOURCE_NONE}>
                    {t('admin.products.transfers.external_label')}
                  </SelectItem>
                  {locations.map((l) => (
                    <SelectItem key={l.id} value={l.id}>
                      {l.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel htmlFor="destination">
                {t('admin.pages.products.transfers.section_to')}
              </FieldLabel>
              <Select value={destinationId} onValueChange={setDestinationId}>
                <SelectTrigger id="destination">
                  <SelectValue placeholder={t('admin.products.transfers.destination_placeholder')}>
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
                <p className="text-sm text-destructive">
                  {t('admin.products.transfers.different_locations_error')}
                </p>
              )}
            </Field>

            <Field>
              <FieldLabel htmlFor="reference">
                {t('admin.products.transfers.reference_label')}
              </FieldLabel>
              <Input
                id="reference"
                placeholder={t('admin.products.transfers.reference_placeholder')}
                value={reference}
                onChange={(e) => setReference(e.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel>{t('admin.pages.products.transfers.section_items')}</FieldLabel>
              <Input
                placeholder={t('admin.products.transfers.search_items_placeholder')}
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
                    <th className="p-3 pl-5 text-left font-normal">
                      {t('admin.products.transfers.items_table.variant')}
                    </th>
                    <th className="p-3 text-left font-normal">
                      {t('admin.products.transfers.items_table.sku')}
                    </th>
                    <th className="p-3 text-right font-normal">
                      {t('admin.products.transfers.items_table.qty')}
                    </th>
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
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            size="sm"
            onClick={handleSubmit}
            disabled={!canSubmit || createMutation.isPending}
          >
            {createMutation.isPending ? t('admin.actions.creating') : t('admin.actions.create')}
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
  const { t } = useTranslation()
  const { data: transfer, isLoading } = useStockTransfer(id)
  const { data: stockLocations } = useStockLocations({ limit: 100 })

  const locationsById = useMemo(() => {
    const map = new Map<string, string>()
    for (const l of stockLocations?.data ?? []) {
      map.set(l.id, l.name)
    }
    return map
  }, [stockLocations])

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
          <SheetTitle>
            {transfer
              ? t('admin.pages.products.transfers.edit_sheet_title', { number: transfer.number })
              : t('admin.pages.products.transfers.sheet_title')}
          </SheetTitle>
          <SheetDescription>
            {transfer?.source_location_id ? (
              <Trans
                i18nKey="admin.pages.products.transfers.description_internal"
                values={{ source: sourceName, destination: destinationName }}
                components={{ strong: <span className="font-medium" /> }}
              />
            ) : (
              <Trans
                i18nKey="admin.pages.products.transfers.description_external"
                values={{ destination: destinationName }}
                components={{ strong: <span className="font-medium" /> }}
              />
            )}
          </SheetDescription>
        </SheetHeader>

        {isLoading || !transfer ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
            <Card>
              <CardHeader>
                <CardTitle>{t('admin.products.transfers.details_card')}</CardTitle>
              </CardHeader>
              <CardContent>
                <dl className="grid grid-cols-3 gap-y-2 text-sm">
                  <dt className="text-muted-foreground">
                    {t('admin.products.transfers.fields.type')}
                  </dt>
                  <dd className="col-span-2">
                    {transfer.source_location_id ? (
                      <Badge variant="outline">
                        <ArrowLeftRightIcon className="size-3" />{' '}
                        {t('admin.products.transfers.fields.internal')}
                      </Badge>
                    ) : (
                      <Badge variant="outline">
                        {t('admin.products.transfers.fields.external_receive')}
                      </Badge>
                    )}
                  </dd>

                  {transfer.reference && (
                    <>
                      <dt className="text-muted-foreground">
                        {t('admin.products.transfers.fields.reference')}
                      </dt>
                      <dd className="col-span-2">{transfer.reference}</dd>
                    </>
                  )}

                  <dt className="text-muted-foreground">
                    {t('admin.products.transfers.fields.created')}
                  </dt>
                  <dd className="col-span-2">
                    <RelativeTime iso={transfer.created_at} />
                  </dd>
                </dl>
              </CardContent>
            </Card>

            <p className="text-xs text-muted-foreground">
              {t('admin.products.transfers.fields.immutable_note')}
            </p>
          </div>
        )}

        <SheetFooter>
          <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            {t('admin.actions.close')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
