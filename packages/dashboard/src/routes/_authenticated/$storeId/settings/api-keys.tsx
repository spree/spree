import { zodResolver } from '@hookform/resolvers/zod'
import { type ApiKey, type ApiKeyCreateParams, SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldLabel,
  FieldTitle,
  Input,
  Popover,
  PopoverContent,
  PopoverTrigger,
  RadioGroup,
  RadioGroupItem,
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
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import type { TFunction } from 'i18next'
import {
  AlertTriangleIcon,
  BanIcon,
  CheckIcon,
  CopyIcon,
  KeyRoundIcon,
  PencilIcon,
  PlusIcon,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import {
  useApiKeys,
  useCreateApiKey,
  useDeleteApiKey,
  useRevokeApiKey,
  useUpdateApiKey,
} from '../../../../hooks/use-api-keys'
import { useChannels } from '../../../../hooks/use-channels'

export const Route = createFileRoute('/_authenticated/$storeId/settings/api-keys')({
  component: ApiKeysSettingsPage,
})

// Scope resource families, in display order — the `read_*` / `write_*` pairs
// recognised by `Spree::ApiKey::SCOPES`. Labels resolve at render time from
// `admin.api_keys.scope_picker.resources.<resource>`. We only render
// `write_*` for resources that ship a write scope (dashboard is read-only).
// Keep this in sync with the server-side allowlist.
const SCOPE_GROUPS: Array<{ resource: string; readOnly?: boolean }> = [
  { resource: 'orders' },
  { resource: 'products' },
  { resource: 'promotions' },
  { resource: 'customers' },
  { resource: 'payments' },
  { resource: 'fulfillments' },
  { resource: 'refunds' },
  { resource: 'gift_cards' },
  { resource: 'store_credits' },
  { resource: 'stock' },
  { resource: 'categories' },
  { resource: 'settings' },
  { resource: 'webhooks' },
  { resource: 'api_keys' },
  { resource: 'dashboard', readOnly: true },
]

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function ApiKeysSettingsPage() {
  const { t } = useTranslation()
  const { data, isLoading } = useApiKeys()
  const { data: channelsData } = useChannels()
  const [createOpen, setCreateOpen] = useState(false)
  const [tokenReveal, setTokenReveal] = useState<ApiKey | null>(null)
  const [editKey, setEditKey] = useState<ApiKey | null>(null)

  const keys = data?.data ?? []
  const publishable = keys.filter((k) => k.key_type === 'publishable')
  const secret = keys.filter((k) => k.key_type === 'secret')

  // Resolve `channel_id → name` for the bound-channel badge on publishable
  // rows. The list is already cached by `useChannels` (shared with the create
  // form), so this is a cheap in-memory lookup.
  const channelName = (channelId: string | null): string | undefined =>
    channelId ? channelsData?.data.find((c) => c.id === channelId)?.name : undefined

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.settings.api_keys.title')}
        subtitle={t('admin.pages.settings.api_keys.subtitle')}
        actions={
          <Button size="sm" onClick={() => setCreateOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.pages.settings.api_keys.new_cta')}
          </Button>
        }
      />

      <ApiKeyTable
        title={t('admin.pages.settings.api_keys.publishable_section')}
        description={t('admin.pages.settings.api_keys.publishable_help')}
        keys={publishable}
        loading={isLoading}
        showScopes={false}
        emptyMessage={t('admin.pages.settings.api_keys.empty_publishable')}
        onEdit={setEditKey}
        channelName={channelName}
      />

      <ApiKeyTable
        title={t('admin.pages.settings.api_keys.secret_section')}
        description={t('admin.pages.settings.api_keys.secret_help')}
        keys={secret}
        loading={isLoading}
        showScopes
        emptyMessage={t('admin.pages.settings.api_keys.empty_secret')}
        onEdit={setEditKey}
      />

      <CreateApiKeyDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onCreated={(key) => {
          setCreateOpen(false)
          // Surface the plaintext token modal only for secret keys — publishable
          // tokens are always readable from the row, so a one-shot reveal would
          // be confusing.
          if (key.key_type === 'secret' && key.plaintext_token) {
            setTokenReveal(key)
          }
        }}
      />

      <TokenRevealDialog
        apiKey={tokenReveal}
        onOpenChange={(open) => {
          if (!open) setTokenReveal(null)
        }}
      />

      <EditApiKeyDialog
        apiKey={editKey}
        onOpenChange={(open) => {
          if (!open) setEditKey(null)
        }}
      />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

function ApiKeyTable({
  title,
  description,
  keys,
  loading,
  showScopes,
  emptyMessage,
  onEdit,
  channelName,
}: {
  title: string
  description: string
  keys: ApiKey[]
  loading: boolean
  showScopes: boolean
  emptyMessage: string
  onEdit: (key: ApiKey) => void
  channelName?: (channelId: string | null) => string | undefined
}) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <p className="text-sm text-muted-foreground">{description}</p>
      </CardHeader>
      <CardContent className="p-0">
        {loading ? (
          <div className="p-4">
            <Skeleton className="h-10 w-full" />
          </div>
        ) : keys.length === 0 ? (
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <KeyRoundIcon />
              </EmptyMedia>
              <EmptyTitle>{emptyMessage}</EmptyTitle>
              <EmptyDescription>{t('admin.api_keys.empty_description')}</EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.fields.name.label')}</TableHead>
                <TableHead>{t('admin.pages.settings.api_keys.table.key')}</TableHead>
                {showScopes && (
                  <TableHead>{t('admin.pages.settings.api_keys.table.scopes')}</TableHead>
                )}
                <TableHead>{t('admin.pages.settings.api_keys.table.last_used_at')}</TableHead>
                <TableHead>{t('admin.fields.created_at.label')}</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {keys.map((key) => (
                <ApiKeyRow
                  key={key.id}
                  apiKey={key}
                  showScopes={showScopes}
                  onEdit={onEdit}
                  channelName={channelName}
                />
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

function ApiKeyRow({
  apiKey,
  showScopes,
  onEdit,
  channelName,
}: {
  apiKey: ApiKey
  showScopes: boolean
  onEdit: (key: ApiKey) => void
  channelName?: (channelId: string | null) => string | undefined
}) {
  const { t } = useTranslation()
  const revokeMutation = useRevokeApiKey()
  const deleteMutation = useDeleteApiKey()
  const confirm = useConfirm()
  const { copied, copy } = useCopyToClipboard()

  const isRevoked = !!apiKey.revoked_at
  // Publishable keys always carry their plaintext token (they're meant to be
  // exposed); secret keys only return `token_prefix` after the one-shot
  // create response.
  const visibleToken = apiKey.plaintext_token ?? apiKey.token_prefix ?? ''
  // Bound publishable keys show their channel; the name may not have loaded yet
  // (channels query pending) — fall back to nothing rather than the raw ID.
  const boundChannelName = channelName?.(apiKey.channel_id)

  async function handleRevoke() {
    const ok = await confirm({
      title: t('admin.api_keys.revoke_confirm.title'),
      message: t('admin.api_keys.revoke_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.revoke'),
    })
    if (!ok) return

    try {
      await revokeMutation.mutateAsync(apiKey.id)
      toast.success(t('admin.messages.key_revoked'))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_revoke_key'))
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.api_keys.delete_confirm.title'),
      message: t('admin.api_keys.delete_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    try {
      await deleteMutation.mutateAsync(apiKey.id)
      toast.success(t('admin.messages.key_deleted'))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.api_keys.errors.failed_to_delete'))
    }
  }

  return (
    <TableRow className={cn(isRevoked && 'opacity-60')}>
      <TableCell>
        <div className="flex items-center gap-2">
          <span className="font-medium">{apiKey.name}</span>
          {boundChannelName && <Badge variant="secondary">{boundChannelName}</Badge>}
          {isRevoked && <Badge variant="destructive">{t('admin.api_keys.badge.revoked')}</Badge>}
        </div>
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-1.5">
          <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{visibleToken}…</code>
          {apiKey.plaintext_token && (
            <Button
              size="icon-xs"
              variant="ghost"
              onClick={() => copy(apiKey.plaintext_token ?? '')}
              aria-label={t('admin.api_keys.dropdown.copy_token_aria')}
            >
              {copied ? <CheckIcon /> : <CopyIcon />}
            </Button>
          )}
        </div>
      </TableCell>
      {showScopes && (
        <TableCell>
          <ScopeList scopes={apiKey.scopes} />
        </TableCell>
      )}
      <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
        {/* `last_used_at` is throttled to update at most hourly (see
            ApiKeyAuthentication#touch_api_key_if_needed), so the timestamp
            won't be perfectly fresh — but it's accurate enough for "is this
            key still in use?" decisions. */}
        <RelativeTime
          iso={apiKey.last_used_at}
          fallback={
            <span className="text-muted-foreground/60">{t('admin.api_keys.badge.never_used')}</span>
          }
        />
      </TableCell>
      <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
        <RelativeTime iso={apiKey.created_at} />
        {apiKey.created_by_email && (
          <div className="text-xs">
            {t('admin.api_keys.by_email', { email: apiKey.created_by_email })}
          </div>
        )}
      </TableCell>
      <TableCell className="text-right">
        <RowActions
          actions={[
            {
              key: 'edit',
              label: t('admin.actions.edit'),
              icon: <PencilIcon className="size-4" />,
              visible: !isRevoked,
              onSelect: () => onEdit(apiKey),
            },
            {
              key: 'revoke',
              label: t('admin.api_keys.dropdown.revoke'),
              icon: <BanIcon className="size-4" />,
              visible: !isRevoked,
              disabled: revokeMutation.isPending,
              onSelect: handleRevoke,
            },
            {
              key: 'delete',
              destructive: true,
              disabled: deleteMutation.isPending,
              onSelect: handleDelete,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}

// Maximum number of scope chips rendered inline before collapsing the rest
// into a `+N` popover. Chosen so a typical row stays under one line at the
// usual table widths.
const SCOPE_PREVIEW_COUNT = 3

function ScopeList({ scopes }: { scopes: string[] }) {
  const { t } = useTranslation()
  if (scopes.includes('write_all')) {
    return <Badge>{t('admin.pages.settings.api_keys.scope_badge.full_access')}</Badge>
  }
  if (scopes.includes('read_all')) {
    return <Badge>{t('admin.pages.settings.api_keys.scope_badge.read_all')}</Badge>
  }
  if (scopes.length === 0) {
    return <span className="text-sm text-muted-foreground">—</span>
  }

  const preview = scopes.slice(0, SCOPE_PREVIEW_COUNT)
  const overflow = scopes.slice(SCOPE_PREVIEW_COUNT)

  return (
    <div className="flex max-w-xs flex-wrap items-center gap-1">
      {preview.map((scope) => (
        <Badge key={scope} className="font-mono text-[10px]">
          {scope}
        </Badge>
      ))}
      {overflow.length > 0 && (
        <Popover>
          {/* `asChild` so the Badge itself becomes the click target — no
              extra button chrome around the chip. */}
          <PopoverTrigger asChild>
            <button
              type="button"
              className="cursor-pointer rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
              aria-label={t('admin.api_keys.scope_picker.show_more_aria', {
                count: overflow.length,
              })}
            >
              <Badge className="font-mono text-[10px] hover:bg-accent">+{overflow.length}</Badge>
            </button>
          </PopoverTrigger>
          <PopoverContent align="start" className="w-auto max-w-sm p-2">
            <div className="flex max-h-60 flex-col gap-1 overflow-y-auto">
              {scopes.map((scope) => (
                <Badge key={scope} className="self-start font-mono text-[10px]">
                  {scope}
                </Badge>
              ))}
            </div>
          </PopoverContent>
        </Popover>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Shared form pieces (create + edit sheets)
// ---------------------------------------------------------------------------

// The name field is identical across the create and edit sheets; both register
// a `name` string field with the same label/placeholder/validation.
function ApiKeyNameField({
  id,
  register,
  error,
}: {
  id: string
  register: ReturnType<typeof useForm<{ name: string }>>['register']
  error?: { message?: string }
}) {
  const { t } = useTranslation()
  return (
    <Field>
      <FieldLabel htmlFor={id}>{t('admin.fields.api_key.name.label')}</FieldLabel>
      <Input
        id={id}
        autoFocus
        placeholder={t('admin.fields.api_key.name.placeholder')}
        aria-invalid={!!error || undefined}
        {...register('name')}
      />
      <FieldError errors={[error]} />
    </Field>
  )
}

function FormErrorBanner({ message }: { message?: string }) {
  if (!message) return null
  return (
    <p className="text-sm text-destructive" role="alert">
      {message}
    </p>
  )
}

// ---------------------------------------------------------------------------
// Create dialog
// ---------------------------------------------------------------------------

// `channel_id` holds the raw channel selection: `''` means "All channels"
// (store-wide) and is dropped on submit; a prefixed `ch_…` binds a publishable
// key to that channel. Only publishable keys can bind — the value is ignored
// (and never sent) for secret keys.
const buildCreateSchema = (t: TFunction) =>
  z
    .object({
      name: z.string().min(1, t('admin.fields.api_key.name.required')),
      key_type: z.enum(['publishable', 'secret']),
      scopes: z.array(z.string()),
      channel_id: z.string(),
    })
    .refine((v) => v.key_type !== 'secret' || v.scopes.length > 0, {
      message: t('admin.api_keys.validation.scope_required'),
      path: ['scopes'],
    })

type CreateFormValues = z.infer<ReturnType<typeof buildCreateSchema>>

// Create UX is a side Sheet (not a Dialog) because the scope grid makes the
// form taller than most viewports — Sheet handles overflow with internal
// scroll and avoids the centered-modal "content cut off" problem.
function CreateApiKeyDialog({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  onCreated: (key: ApiKey) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateApiKey()

  const form = useForm<CreateFormValues>({
    resolver: zodResolver(buildCreateSchema(t)),
    defaultValues: { name: '', key_type: 'secret', scopes: [], channel_id: '' },
  })

  const keyType = form.watch('key_type')

  async function onSubmit(values: CreateFormValues) {
    const isPublishable = values.key_type === 'publishable'
    const params: ApiKeyCreateParams = {
      name: values.name,
      key_type: values.key_type,
      scopes: isPublishable ? undefined : values.scopes,
      // Channel binding is publishable-only; omit for secret keys and for the
      // "All channels" default (empty string) so the key stays store-wide.
      channel_id: isPublishable && values.channel_id ? values.channel_id : undefined,
    }
    try {
      const key = await createMutation.mutateAsync(params)
      toast.success(t('admin.messages.key_created'))
      form.reset({ name: '', key_type: 'secret', scopes: [], channel_id: '' })
      onCreated(key)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.api_keys.errors.failed_to_create'))
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset({ name: '', key_type: 'secret', scopes: [], channel_id: '' })
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.api_keys.create_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.api_keys.create_sheet_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          {/* `flex-1 overflow-y-auto` keeps the footer pinned while the body
              scrolls when the scope grid overflows. */}
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FormErrorBanner message={form.formState.errors.root?.message} />
            <ApiKeyNameField
              id="api-key-name"
              register={form.register}
              error={form.formState.errors.name}
            />

            <Field>
              <FieldLabel>{t('admin.fields.api_key.key_type.label')}</FieldLabel>
              <Controller
                name="key_type"
                control={form.control}
                render={({ field }) => (
                  <RadioGroup value={field.value} onValueChange={(value) => field.onChange(value)}>
                    <KeyTypeChoice
                      value="secret"
                      title={t('admin.api_keys.key_type.secret_title')}
                      description={t('admin.api_keys.key_type.secret_description')}
                    />
                    <KeyTypeChoice
                      value="publishable"
                      title={t('admin.api_keys.key_type.publishable_title')}
                      description={t('admin.api_keys.key_type.publishable_description')}
                    />
                  </RadioGroup>
                )}
              />
            </Field>

            {keyType === 'publishable' && (
              <Field>
                <FieldLabel htmlFor="api-key-channel">
                  {t('admin.fields.api_key.channel.label')}
                </FieldLabel>
                <Controller
                  name="channel_id"
                  control={form.control}
                  render={({ field }) => (
                    <ChannelBindingSelect
                      id="api-key-channel"
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
                <p className="text-xs text-muted-foreground">
                  {t('admin.fields.api_key.channel.help')}
                </p>
              </Field>
            )}

            {keyType === 'secret' && (
              <Field>
                <FieldLabel>{t('admin.fields.api_key.scopes.label')}</FieldLabel>
                <Controller
                  name="scopes"
                  control={form.control}
                  render={({ field }) => (
                    <ScopePicker value={field.value} onChange={field.onChange} />
                  )}
                />
                {form.formState.errors.scopes && (
                  <p className="text-sm text-destructive">{form.formState.errors.scopes.message}</p>
                )}
              </Field>
            )}
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.api_keys.create_key_cta')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Edit sheet (name only — scopes are fixed for the life of a key)
// ---------------------------------------------------------------------------

type EditFormValues = { name: string }

// Lifted dialog (one instance per page, driven by `apiKey`) — mirrors
// TokenRevealDialog. Only `name` is editable; secret keys show their scopes
// disabled since scopes are fixed for the life of a key.
function EditApiKeyDialog({
  apiKey,
  onOpenChange,
}: {
  apiKey: ApiKey | null
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateApiKey()

  const form = useForm<EditFormValues>({
    resolver: zodResolver(
      z.object({ name: z.string().min(1, t('admin.fields.api_key.name.required')) }),
    ),
    defaultValues: { name: '' },
  })

  // Re-sync the form when a different key is opened. `defaultValues` alone won't
  // update across opens (the dialog is mounted once and reused), so reset
  // explicitly when the key changes.
  useEffect(() => {
    if (apiKey) form.reset({ name: apiKey.name })
  }, [apiKey, form])

  async function onSubmit(values: EditFormValues) {
    if (!apiKey) return
    try {
      await updateMutation.mutateAsync({ id: apiKey.id, params: { name: values.name } })
      toast.success(t('admin.messages.key_updated'))
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.api_keys.errors.failed_to_update'))
    }
  }

  return (
    <Sheet open={!!apiKey} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.api_keys.edit_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.api_keys.edit_sheet_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FormErrorBanner message={form.formState.errors.root?.message} />
            <ApiKeyNameField
              id="edit-api-key-name"
              register={form.register}
              error={form.formState.errors.name}
            />

            {apiKey?.key_type === 'secret' && apiKey.scopes.length > 0 && (
              <Field>
                <FieldLabel>{t('admin.fields.api_key.scopes.label')}</FieldLabel>
                {/* Scopes are fixed for the life of a key — rendered disabled.
                    To change authority, create a new key and revoke this one. */}
                <ScopePicker value={apiKey.scopes} disabled />
                <p className="text-xs text-muted-foreground">
                  {t('admin.api_keys.scopes_immutable_help')}
                </p>
              </Field>
            )}
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// Sentinel for the "All channels" (store-wide) option. Base UI's `<Select>`
// treats an empty string value as "no selection" and shows the placeholder, so
// the store-wide choice carries this non-empty value and is mapped back to `''`
// (the schema's store-wide value) at the boundary.
const ALL_CHANNELS = '__all__'

// Channel binding picker for publishable keys. Unlike the shared
// `<ChannelSelect>`, the first option is "All channels" (store-wide) so a key
// can be left unbound, which is the default. Emits `''` for store-wide and a
// prefixed `ch_…` for a bound channel.
function ChannelBindingSelect({
  id,
  value,
  onChange,
}: {
  id: string
  value: string
  onChange: (channelId: string) => void
}) {
  const { t } = useTranslation()
  const { data } = useChannels()
  const channels = data?.data ?? []

  const allChannelsLabel = t('admin.fields.api_key.channel.all_channels')

  return (
    <Select
      value={value === '' ? ALL_CHANNELS : value}
      onValueChange={(v) => onChange(v === ALL_CHANNELS ? '' : v)}
    >
      <SelectTrigger id={id}>
        {/* Base UI's `<SelectValue>` renders the raw value (the prefixed ID);
            the children render-prop resolves the channel name from the cached
            list so the trigger matches the selected item. */}
        <SelectValue>
          {(v) =>
            v === ALL_CHANNELS
              ? allChannelsLabel
              : (channels.find((c) => c.id === v)?.name ?? allChannelsLabel)
          }
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={ALL_CHANNELS}>{allChannelsLabel}</SelectItem>
        {channels.map((c) => (
          <SelectItem key={c.id} value={c.id}>
            {c.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function KeyTypeChoice({
  value,
  title,
  description,
}: {
  value: 'publishable' | 'secret'
  title: string
  description: string
}) {
  return (
    <FieldLabel>
      <Field orientation="horizontal">
        <FieldContent>
          <FieldTitle>{title}</FieldTitle>
          <FieldDescription>{description}</FieldDescription>
        </FieldContent>
        <RadioGroupItem value={value} />
      </Field>
    </FieldLabel>
  )
}

// `disabled` renders the whole picker read-only — used when editing an existing
// key, whose scopes are fixed for its lifetime (the server rejects scope edits).
function ScopePicker({
  value,
  onChange,
  disabled = false,
}: {
  value: string[]
  onChange?: (next: string[]) => void
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const hasWriteAll = value.includes('write_all')
  const hasReadAll = value.includes('read_all')

  function toggleScope(scope: string) {
    onChange?.(value.includes(scope) ? value.filter((v) => v !== scope) : [...value, scope])
  }

  function setAllRead(checked: boolean) {
    let next = value.filter((v) => v !== 'read_all' && !v.startsWith('read_'))
    if (checked) next = [...next, 'read_all']
    onChange?.(next)
  }

  function setAllWrite(checked: boolean) {
    let next = value.filter((v) => v !== 'write_all' && !v.startsWith('write_'))
    if (checked) next = [...next, 'write_all']
    onChange?.(next)
  }

  return (
    <div
      className={cn(
        'flex flex-col gap-3 rounded-md border border-border',
        disabled && 'opacity-70',
      )}
    >
      {/* Quick access: write_all / read_all toggles. Selecting one blocks the
          per-resource grid because the catch-all already covers it. */}
      <div className="flex flex-col gap-2 border-b border-border bg-muted/30 p-3">
        <label htmlFor="scope-write-all" className="flex cursor-pointer items-center gap-2 text-sm">
          <Checkbox
            id="scope-write-all"
            checked={hasWriteAll}
            onCheckedChange={setAllWrite}
            disabled={disabled}
          />
          <span className="font-medium">{t('admin.api_keys.scope_picker.full_access_label')}</span>
          <span className="text-xs text-muted-foreground">
            {t('admin.api_keys.scope_picker.full_access_hint')}
          </span>
        </label>
        <label htmlFor="scope-read-all" className="flex cursor-pointer items-center gap-2 text-sm">
          <Checkbox
            id="scope-read-all"
            checked={hasReadAll}
            onCheckedChange={setAllRead}
            disabled={disabled || hasWriteAll}
          />
          <span className="font-medium">{t('admin.api_keys.scope_picker.read_all_label')}</span>
          <span className="text-xs text-muted-foreground">
            {t('admin.api_keys.scope_picker.read_all_hint')}
          </span>
        </label>
      </div>

      <div
        className={cn(
          'grid grid-cols-[1fr_auto_auto] gap-x-4 gap-y-2 p-3 text-sm',
          !disabled && (hasWriteAll || hasReadAll) && 'pointer-events-none opacity-50',
        )}
      >
        <span className="font-medium text-muted-foreground">
          {t('admin.api_keys.scope_picker.resource_header')}
        </span>
        <span className="font-medium text-muted-foreground">
          {t('admin.api_keys.scope_picker.read_header')}
        </span>
        <span className="font-medium text-muted-foreground">
          {t('admin.api_keys.scope_picker.write_header')}
        </span>
        {SCOPE_GROUPS.map((group) => {
          const readScope = `read_${group.resource}`
          const writeScope = `write_${group.resource}`
          const hasRead = value.includes(readScope) || value.includes(writeScope)
          const hasWrite = value.includes(writeScope)
          return (
            <ScopeRow
              key={group.resource}
              label={t(`admin.api_keys.scope_picker.resources.${group.resource}`)}
              hasRead={hasRead}
              hasWrite={hasWrite}
              readOnly={group.readOnly}
              disabled={disabled}
              onToggleRead={() => toggleScope(readScope)}
              onToggleWrite={() => {
                // Toggling write also implies read on the server, but we keep
                // them as separate checkboxes to make the user's intent
                // explicit. If they tick write without read, the server
                // grants read implicitly via `has_scope?`.
                toggleScope(writeScope)
              }}
            />
          )
        })}
      </div>
    </div>
  )
}

function ScopeRow({
  label,
  hasRead,
  hasWrite,
  readOnly,
  disabled,
  onToggleRead,
  onToggleWrite,
}: {
  label: string
  hasRead: boolean
  hasWrite: boolean
  readOnly?: boolean
  disabled?: boolean
  onToggleRead: () => void
  onToggleWrite: () => void
}) {
  const { t } = useTranslation()
  return (
    <>
      <span>{label}</span>
      <Checkbox
        checked={hasRead}
        onCheckedChange={onToggleRead}
        // Checking write implies read; reflect that here so the UI doesn't
        // look out of sync with what the server will enforce.
        disabled={disabled || hasWrite}
        aria-label={t('admin.api_keys.scope_picker.read_aria', { resource: label })}
        className="justify-self-center"
      />
      {readOnly ? (
        <span className="text-xs text-muted-foreground justify-self-center">—</span>
      ) : (
        <Checkbox
          checked={hasWrite}
          onCheckedChange={onToggleWrite}
          disabled={disabled}
          aria-label={t('admin.api_keys.scope_picker.write_aria', { resource: label })}
          className="justify-self-center"
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Token reveal dialog (one-shot, on create)
// ---------------------------------------------------------------------------

function TokenRevealDialog({
  apiKey,
  onOpenChange,
}: {
  apiKey: ApiKey | null
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { copied, copy } = useCopyToClipboard()

  return (
    <Dialog open={!!apiKey} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.settings.api_keys.save_secret_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.pages.settings.api_keys.save_secret_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-3">
          <div className="flex items-start gap-2 rounded-md border border-yellow-200 bg-yellow-50 p-3 text-sm text-yellow-900 dark:border-yellow-900/40 dark:bg-yellow-950/40 dark:text-yellow-200">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>{t('admin.api_keys.warning_treat_like_password')}</span>
          </div>
          {apiKey?.plaintext_token && (
            <div className="flex items-center gap-2 rounded-md border border-border bg-muted/40 p-3">
              <code className="flex-1 truncate font-mono text-sm">{apiKey.plaintext_token}</code>
              <Button
                size="sm"
                variant="outline"
                onClick={() => copy(apiKey.plaintext_token ?? '')}
              >
                {copied ? <CheckIcon /> : <CopyIcon />}
                {copied ? t('admin.actions.copied') : t('admin.actions.copy')}
              </Button>
            </div>
          )}
        </DialogBody>
        <DialogFooter>
          <Button size="sm" onClick={() => onOpenChange(false)}>
            {t('admin.actions.done')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
