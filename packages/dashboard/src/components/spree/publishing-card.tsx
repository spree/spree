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
  Item,
  ItemActions,
  ItemContent,
  ItemMedia,
  ItemTitle,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { GlobeIcon, PencilIcon, SettingsIcon } from '@spree/dashboard-ui/icons'
import { parseISO } from 'date-fns'
import { useEffect, useMemo, useRef, useState } from 'react'
import {
  type ArrayPath,
  Controller,
  type FieldArray,
  type FieldValues,
  type Path,
  type UseFormReturn,
  useFieldArray,
} from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useChannels } from '../../hooks/use-channels'

/** One row of a publications array — a product's or a collection's. */
interface PublicationValue {
  channel_id: string
  published_at?: string | null
  unpublished_at?: string | null
}

/**
 * Where the card reads and writes. `name` is the record's publications array
 * (`product_publications`, `publications`); `statusField` names a status
 * that gates visibility on top of the channel windows (a product's Draft or
 * Archived status); `seed` fills an untouched new form once channels load.
 */
interface PublishingTarget<T extends FieldValues> {
  form: UseFormReturn<T>
  name: ArrayPath<T>
  statusField?: Path<T>
  /** `default`: the store's default channel. `active`: every active channel. */
  seed?: 'default' | 'active'
  /** Locale namespace holding `publishing.empty` and `publishing.manage_description`. */
  translationNamespace?: string
}

// `not_available` short-circuits when the record's status (a Draft or Archived
// product) blocks customer visibility, even if the per-channel window is open.
type ScheduleStatus = 'live' | 'scheduled' | 'hidden' | 'not_available'

function scheduleStatus(
  status: string | undefined,
  gated: boolean,
  publishedAt?: string | null,
  unpublishedAt?: string | null,
): ScheduleStatus {
  if (gated && status !== 'active') return 'not_available'
  const now = Date.now()
  if (unpublishedAt && parseISO(unpublishedAt).getTime() <= now) return 'hidden'
  if (publishedAt && parseISO(publishedAt).getTime() > now) return 'scheduled'
  return 'live'
}

export function PublishingCard<T extends FieldValues>({
  form,
  name,
  statusField,
  seed,
  translationNamespace = 'admin.pages.products',
}: PublishingTarget<T>) {
  const { t } = useTranslation()
  const [manageOpen, setManageOpen] = useState(false)
  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const { data: channelsResponse } = useChannels()
  const channelsById = useMemo(
    () => new Map((channelsResponse?.data ?? []).map((c) => [c.id, c])),
    [channelsResponse?.data],
  )
  const publicationsArray = useFieldArray({ control: form.control, name, keyName: '_key' })
  const rows = publicationsArray.fields as unknown as Array<PublicationValue & { _key: string }>

  // Seed the channels once (the store's default on a new product, every
  // active channel on a new collection, matching what the server does when
  // a create omits publications). useFieldArray maintains its own
  // internal list of fields keyed by `_key`. Two pitfalls to avoid:
  // - `useFieldArray.append` unconditionally flips `isDirty=true`, which
  //   would surface the Discard button, enable Save on an empty form,
  //   and fire the beforeunload warning on mount.
  // - `form.setValue(name, ..., { shouldDirty: false })` doesn't emit a
  //   dirty-fields event, but `form.formState.isDirty` is computed by
  //   diffing current values against defaults — so the seeded array
  //   still reads as dirty unless we update defaults too.
  //
  // Solution: `form.reset` with the seed merged into the form's pristine
  // defaults, snapshotted via `getValues()` on FIRST render — at that
  // moment values ARE the defaults, and `getValues()` is synchronously
  // complete. `keepDirtyValues: true` preserves anything the merchant
  // typed before channels resolved, dirty flags included. Do NOT source
  // the reset from `formState.defaultValues`: it sits behind RHF's lazy
  // proxy and can read back empty inside an effect, and resetting with
  // that object silently wipes the rest of the form (the new-product page
  // lost its seeded default variant whenever the channels query resolved
  // from a warm cache). `resetField`/`setValue` pairs don't work either —
  // an array root isn't a registered field, so they miss values or
  // defaults.
  //
  // Guard with a ref so the merchant unticking the seeded channel doesn't
  // re-add it on the next render.
  //
  // Filter on `active` so deactivated default channels don't auto-seed. A
  // merchant who flips Online Store inactive (e.g. during maintenance)
  // would otherwise get products published to a channel the storefront
  // filters out — invisible products without a warning in the admin.
  const activeChannels = (channelsResponse?.data ?? []).filter((c) => c.active)
  const seedIds = (
    seed === 'active' ? activeChannels : activeChannels.filter((c) => c.default)
  ).map((c) => c.id)
  const seedKey = seed ? seedIds.join(',') : ''
  const seededRef = useRef(false)
  const pristineDefaultsRef = useRef<T | null>(null)
  if (seed && pristineDefaultsRef.current === null) {
    pristineDefaultsRef.current = form.getValues()
  }
  useEffect(() => {
    if (!seed) return
    if (seededRef.current) return
    if (!seedKey) return
    seededRef.current = true
    if (publicationsArray.fields.length > 0) return
    form.reset(
      {
        ...(pristineDefaultsRef.current as T),
        [name]: seedKey
          .split(',')
          .map((channel_id) => ({ channel_id, published_at: null, unpublished_at: null })),
      },
      { keepDirtyValues: true },
    )
  }, [seed, seedKey, name, publicationsArray, form])

  const channelName = (id: string) => channelsById.get(id)?.name ?? channelsById.get(id)?.code ?? id

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-2">
        <CardTitle>
          <GlobeIcon className="size-4" />
          {t('admin.pages.products.publishing.title')}
        </CardTitle>
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
        {rows.length === 0 && (
          <p className="text-sm text-muted-foreground">
            {t(`${translationNamespace}.publishing.empty`)}
          </p>
        )}
        {rows.map((row, index) =>
          editingIndex === index ? (
            <PublicationEditor
              key={row._key}
              form={form}
              path={`${name}.${index}`}
              channelName={channelName(row.channel_id)}
              onDone={() => setEditingIndex(null)}
            />
          ) : (
            <PublicationRow
              key={row._key}
              form={form}
              path={`${name}.${index}`}
              statusField={statusField}
              channelName={channelName(row.channel_id)}
              onEdit={() => setEditingIndex(index)}
            />
          ),
        )}
      </CardContent>
      <ManageChannelsSheet
        open={manageOpen}
        onOpenChange={setManageOpen}
        rows={rows}
        description={t(`${translationNamespace}.publishing.manage_description`)}
        onAdd={(channelId) =>
          publicationsArray.append({
            channel_id: channelId,
            published_at: null,
            unpublished_at: null,
          } as FieldArray<T, ArrayPath<T>>)
        }
        onRemove={(index) => publicationsArray.remove(index)}
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

function PublicationRow<T extends FieldValues>({
  form,
  path,
  statusField,
  channelName,
  onEdit,
}: {
  form: UseFormReturn<T>
  path: string
  statusField?: Path<T>
  channelName: string
  onEdit: () => void
}) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const [publishedAt, unpublishedAt] = form.watch([
    `${path}.published_at` as Path<T>,
    `${path}.unpublished_at` as Path<T>,
  ]) as [string | null | undefined, string | null | undefined]
  const recordStatus = statusField ? (form.watch(statusField) as string | undefined) : undefined
  const status = scheduleStatus(recordStatus, Boolean(statusField), publishedAt, unpublishedAt)

  const caption = (() => {
    const start = publishedAt ? formatStoreDateTime(publishedAt, timezone) : null
    const end = unpublishedAt ? formatStoreDateTime(unpublishedAt, timezone) : null
    if (status === 'not_available') {
      const productStatusLabel = t(`admin.pages.products.status_options.${recordStatus ?? 'draft'}`)
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
      className="group flex w-full items-start justify-between gap-3 rounded-md px-2 py-2 text-left hover:bg-accent cursor-pointer"
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

function PublicationEditor<T extends FieldValues>({
  form,
  path,
  channelName,
  onDone,
}: {
  form: UseFormReturn<T>
  path: string
  channelName: string
  onDone: () => void
}) {
  const { t } = useTranslation()
  const publishedAtPath = `${path}.published_at` as Path<T>
  const unpublishedAtPath = `${path}.unpublished_at` as Path<T>

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
  rows,
  description,
  onAdd,
  onRemove,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  rows: PublicationValue[]
  description: string
  onAdd: (channelId: string) => void
  onRemove: (index: number) => void
}) {
  const { t } = useTranslation()
  const { data: channelsResponse, isLoading } = useChannels()
  const channels = channelsResponse?.data ?? []

  const toggle = (channel: Channel, checked: boolean) => {
    const existingIndex = rows.findIndex((row) => row.channel_id === channel.id)
    if (checked && existingIndex === -1) onAdd(channel.id)
    else if (!checked && existingIndex !== -1) onRemove(existingIndex)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.products.publishing.manage_title')}</SheetTitle>
          <SheetDescription>{description}</SheetDescription>
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
              const checked = rows.some((row) => row.channel_id === channel.id)
              return (
                <Item
                  key={channel.id}
                  variant="outline"
                  size="sm"
                  render={<button type="button" />}
                  onClick={() => toggle(channel, !checked)}
                  className="cursor-pointer bg-background text-left hover:bg-accent"
                >
                  <ItemMedia>
                    <Checkbox checked={checked} tabIndex={-1} />
                  </ItemMedia>
                  <ItemContent>
                    <ItemTitle className="font-normal">
                      {channel.name ?? channel.code ?? channel.id}
                    </ItemTitle>
                  </ItemContent>
                  {!channel.active && (
                    <ItemActions className="text-xs text-muted-foreground">
                      {t('admin.pages.products.publishing.inactive_marker')}
                    </ItemActions>
                  )}
                </Item>
              )
            })}
        </div>
        <SheetFooter>
          <Button type="button" onClick={() => onOpenChange(false)}>
            {t('admin.actions.done')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
