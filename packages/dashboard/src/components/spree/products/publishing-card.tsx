import type { Channel } from '@spree/admin-sdk'
import { formatStoreDateTime, StoreDatePicker, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  Field,
  FieldLabel,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { parseISO } from 'date-fns'
import { PencilIcon, SettingsIcon } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Controller, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useChannels } from '@/hooks/use-channels'
import type { ProductFormValues } from '@/schemas/product'

type ProductForm = UseFormReturn<ProductFormValues>

// `not_available` short-circuits when the product status (Draft/Archived) blocks
// customer visibility, even if the per-channel publication window is open. Product
// status is the outer gate; per-channel scheduling only matters once status is Active.
type ScheduleStatus = 'live' | 'scheduled' | 'hidden' | 'not_available'

function scheduleStatus(
  productStatus: ProductFormValues['status'] | undefined,
  publishedAt?: string | null,
  unpublishedAt?: string | null,
): ScheduleStatus {
  if (productStatus !== 'active') return 'not_available'
  const now = Date.now()
  if (unpublishedAt && parseISO(unpublishedAt).getTime() <= now) return 'hidden'
  if (publishedAt && parseISO(publishedAt).getTime() > now) return 'scheduled'
  return 'live'
}

export function PublishingCard({
  form,
  seedDefaultChannel = false,
}: {
  form: ProductForm
  /**
   * On the New Product page, seed the store's default channel into the
   * publications array once channels resolve, so the merchant doesn't have
   * to open Manage before save. Only fires when the array is empty and
   * untouched. Default false: the edit page uses persisted publications
   * verbatim — no auto-seeding.
   */
  seedDefaultChannel?: boolean
}) {
  const { t } = useTranslation()
  const [manageOpen, setManageOpen] = useState(false)
  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const { data: channelsResponse } = useChannels()
  const channelsById = useMemo(
    () => new Map((channelsResponse?.data ?? []).map((c) => [c.id, c])),
    [channelsResponse?.data],
  )
  const publicationsArray = useFieldArray({
    control: form.control,
    name: 'product_publications',
    keyName: '_key',
  })

  // Seed the default channel once. useFieldArray maintains its own internal
  // list of fields keyed by `_key` — calling `form.setValue` from the parent
  // bypasses that bookkeeping, so the parent route can't reliably populate
  // it. Owning the seed here means the field array stays in charge.
  //
  // Guard with a ref so the merchant unticking the seeded channel doesn't
  // re-add it on the next render.
  const defaultChannelId = channelsResponse?.data.find((c) => c.default)?.id
  const seededRef = useRef(false)
  useEffect(() => {
    if (!seedDefaultChannel) return
    if (seededRef.current) return
    if (!defaultChannelId) return
    if (publicationsArray.fields.length > 0) {
      seededRef.current = true
      return
    }
    seededRef.current = true
    publicationsArray.append({
      channel_id: defaultChannelId,
      published_at: null,
      unpublished_at: null,
    })
  }, [seedDefaultChannel, defaultChannelId, publicationsArray])

  const channelName = (id: string) => channelsById.get(id)?.name ?? channelsById.get(id)?.code ?? id

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-2">
        <CardTitle>{t('admin.pages.products.publishing.title')}</CardTitle>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => setManageOpen(true)}
          aria-label={t('admin.pages.products.publishing.manage_cta')}
        >
          <SettingsIcon className="size-4" />
          {t('admin.pages.products.publishing.manage_cta')}
        </Button>
      </CardHeader>
      <CardContent className="flex flex-col gap-1">
        {publicationsArray.fields.length === 0 && (
          <p className="text-sm text-muted-foreground">
            {t('admin.pages.products.publishing.empty')}
          </p>
        )}
        {publicationsArray.fields.map((row, index) =>
          editingIndex === index ? (
            <PublicationEditor
              key={row._key}
              form={form}
              index={index}
              channelName={channelName(row.channel_id)}
              onDone={() => setEditingIndex(null)}
            />
          ) : (
            <PublicationRow
              key={row._key}
              form={form}
              index={index}
              channelName={channelName(row.channel_id)}
              onEdit={() => setEditingIndex(index)}
            />
          ),
        )}
      </CardContent>
      <ManageChannelsSheet
        open={manageOpen}
        onOpenChange={setManageOpen}
        publicationsArray={publicationsArray}
      />
    </Card>
  )
}

function StatusDot({ status }: { status: ScheduleStatus }) {
  const cls =
    status === 'live'
      ? 'bg-emerald-500'
      : status === 'scheduled'
        ? 'bg-amber-500'
        : 'bg-muted-foreground'
  return <span className={`inline-block size-2 rounded-full ${cls}`} aria-hidden />
}

function PublicationRow({
  form,
  index,
  channelName,
  onEdit,
}: {
  form: ProductForm
  index: number
  channelName: string
  onEdit: () => void
}) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const [productStatus, publishedAt, unpublishedAt] = form.watch([
    'status',
    `product_publications.${index}.published_at`,
    `product_publications.${index}.unpublished_at`,
  ])
  const status = scheduleStatus(productStatus, publishedAt, unpublishedAt)

  const caption = (() => {
    const start = publishedAt ? formatStoreDateTime(publishedAt, timezone) : null
    const end = unpublishedAt ? formatStoreDateTime(unpublishedAt, timezone) : null
    if (status === 'not_available') {
      const productStatusLabel = t(
        `admin.pages.products.status_options.${productStatus ?? 'draft'}`,
      )
      return t('admin.pages.products.publishing.caption_not_available', {
        product_status: productStatusLabel,
      })
    }
    if (status === 'hidden') {
      return t('admin.pages.products.publishing.caption_unpublished', { date: end })
    }
    if (status === 'scheduled') {
      return end
        ? t('admin.pages.products.publishing.caption_window', { start, end })
        : t('admin.pages.products.publishing.caption_scheduled', { date: start })
    }
    // live
    if (end) return t('admin.pages.products.publishing.caption_hidden_after', { date: end })
    return t('admin.pages.products.publishing.caption_live')
  })()

  return (
    <button
      type="button"
      onClick={onEdit}
      className="group flex w-full items-start justify-between gap-3 rounded-md px-2 py-2 text-left hover:bg-muted/40"
    >
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <div className="flex items-center gap-2">
          <span className="truncate text-sm font-medium">{channelName}</span>
          <span className="flex items-center gap-1 text-xs text-muted-foreground">
            <StatusDot status={status} />
            {t(`admin.pages.products.publishing.status_${status}`)}
          </span>
        </div>
        <span className="text-xs text-muted-foreground">{caption}</span>
      </div>
      <PencilIcon className="mt-0.5 size-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
    </button>
  )
}

function PublicationEditor({
  form,
  index,
  channelName,
  onDone,
}: {
  form: ProductForm
  index: number
  channelName: string
  onDone: () => void
}) {
  const { t } = useTranslation()
  const publishedAtPath = `product_publications.${index}.published_at` as const
  const unpublishedAtPath = `product_publications.${index}.unpublished_at` as const

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-muted/20 px-3 py-3">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium">{channelName}</span>
        <Button type="button" variant="ghost" size="sm" className="h-7 text-xs" onClick={onDone}>
          {t('admin.actions.done')}
        </Button>
      </div>

      <Field>
        <FieldLabel>{t('admin.fields.product_publication.published_at.label')}</FieldLabel>
        <Controller
          control={form.control}
          name={publishedAtPath}
          render={({ field }) => (
            <StoreDatePicker
              value={field.value ?? null}
              onChange={(next) => field.onChange(next ?? null)}
              placeholder={t('admin.fields.product_publication.published_at.placeholder')}
              includeTime
              inline
            />
          )}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.product_publication.published_at.help')}
        </span>
      </Field>

      <Field>
        <FieldLabel>{t('admin.fields.product_publication.unpublished_at.label')}</FieldLabel>
        <Controller
          control={form.control}
          name={unpublishedAtPath}
          render={({ field }) => (
            <StoreDatePicker
              value={field.value ?? null}
              onChange={(next) => field.onChange(next ?? null)}
              placeholder={t('admin.fields.product_publication.unpublished_at.placeholder')}
              includeTime
              inline
            />
          )}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.product_publication.unpublished_at.help')}
        </span>
      </Field>
    </div>
  )
}

function ManageChannelsSheet({
  open,
  onOpenChange,
  publicationsArray,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  publicationsArray: ReturnType<
    typeof useFieldArray<ProductFormValues, 'product_publications', '_key'>
  >
}) {
  const { t } = useTranslation()
  const { data: channelsResponse, isLoading } = useChannels()
  const channels = channelsResponse?.data ?? []

  const toggle = (channel: Channel, checked: boolean) => {
    const existingIndex = publicationsArray.fields.findIndex((f) => f.channel_id === channel.id)
    if (checked && existingIndex === -1) {
      publicationsArray.append({
        channel_id: channel.id,
        published_at: null,
        unpublished_at: null,
      })
    } else if (!checked && existingIndex !== -1) {
      publicationsArray.remove(existingIndex)
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.products.publishing.manage_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.pages.products.publishing.manage_description')}
          </SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto p-4">
          {isLoading && (
            <>
              <Skeleton className="h-9 w-full" />
              <Skeleton className="h-9 w-full" />
              <Skeleton className="h-9 w-full" />
            </>
          )}
          {!isLoading && channels.length === 0 && (
            <p className="text-sm text-muted-foreground">
              {t('admin.pages.products.publishing.no_channels')}
            </p>
          )}
          {!isLoading &&
            channels.map((channel) => {
              const checked = publicationsArray.fields.some((f) => f.channel_id === channel.id)
              return (
                <button
                  key={channel.id}
                  type="button"
                  onClick={() => toggle(channel, !checked)}
                  className="flex w-full cursor-pointer items-center gap-3 rounded-md border border-border bg-background px-3 py-2 text-left hover:bg-muted/40"
                >
                  <Checkbox checked={checked} tabIndex={-1} />
                  <span className="flex-1 text-sm">
                    {channel.name ?? channel.code ?? channel.id}
                  </span>
                  {!channel.active && (
                    <span className="text-xs text-muted-foreground">
                      {t('admin.pages.products.publishing.inactive_marker')}
                    </span>
                  )}
                </button>
              )
            })}
        </div>
        <SheetFooter>
          <Button type="button" size="sm" onClick={() => onOpenChange(false)}>
            {t('admin.actions.done')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
