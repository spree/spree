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
import {
  AlertTriangleIcon,
  BanIcon,
  CheckIcon,
  CopyIcon,
  KeyRoundIcon,
  PlusIcon,
} from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { useApiKeys, useCreateApiKey, useDeleteApiKey, useRevokeApiKey } from '@/hooks/use-api-keys'

export const Route = createFileRoute('/_authenticated/$storeId/settings/api-keys')({
  component: ApiKeysSettingsPage,
})

// Scope groups, in display order. Each entry maps a resource label to the
// `read_*` and `write_*` scopes recognised by `Spree::ApiKey::SCOPES`. We
// only render `write_*` for resources that ship a write scope (dashboard
// is read-only). Keep this in sync with the server-side allowlist.
const SCOPE_GROUPS: Array<{ label: string; resource: string; readOnly?: boolean }> = [
  { label: 'Orders', resource: 'orders' },
  { label: 'Products', resource: 'products' },
  { label: 'Customers', resource: 'customers' },
  { label: 'Payments', resource: 'payments' },
  { label: 'Fulfillments', resource: 'fulfillments' },
  { label: 'Refunds', resource: 'refunds' },
  { label: 'Gift cards', resource: 'gift_cards' },
  { label: 'Store credits', resource: 'store_credits' },
  { label: 'Categories', resource: 'categories' },
  { label: 'Custom field definitions', resource: 'custom_field_definitions' },
  { label: 'Settings', resource: 'settings' },
  { label: 'Webhooks', resource: 'webhooks' },
  { label: 'Dashboard', resource: 'dashboard', readOnly: true },
]

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function ApiKeysSettingsPage() {
  const { t } = useTranslation()
  const { data, isLoading } = useApiKeys()
  const [createOpen, setCreateOpen] = useState(false)
  const [tokenReveal, setTokenReveal] = useState<ApiKey | null>(null)

  const keys = data?.data ?? []
  const publishable = keys.filter((k) => k.key_type === 'publishable')
  const secret = keys.filter((k) => k.key_type === 'secret')

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
      />

      <ApiKeyTable
        title={t('admin.pages.settings.api_keys.secret_section')}
        description={t('admin.pages.settings.api_keys.secret_help')}
        keys={secret}
        loading={isLoading}
        showScopes
        emptyMessage={t('admin.pages.settings.api_keys.empty_secret')}
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
}: {
  title: string
  description: string
  keys: ApiKey[]
  loading: boolean
  showScopes: boolean
  emptyMessage: string
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
                <TableHead>{t('admin.pages.settings.api_keys.table.name')}</TableHead>
                <TableHead>{t('admin.pages.settings.api_keys.table.key')}</TableHead>
                {showScopes && (
                  <TableHead>{t('admin.pages.settings.api_keys.table.scopes')}</TableHead>
                )}
                <TableHead>{t('admin.pages.settings.api_keys.table.last_used_at')}</TableHead>
                <TableHead>{t('admin.pages.settings.api_keys.table.created_at')}</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {keys.map((key) => (
                <ApiKeyRow key={key.id} apiKey={key} showScopes={showScopes} />
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

function ApiKeyRow({ apiKey, showScopes }: { apiKey: ApiKey; showScopes: boolean }) {
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
              aria-label={`Show ${overflow.length} more scope${overflow.length === 1 ? '' : 's'}`}
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
// Create dialog
// ---------------------------------------------------------------------------

const createSchema = z
  .object({
    name: z.string().min(1, 'Name is required'),
    key_type: z.enum(['publishable', 'secret']),
    scopes: z.array(z.string()),
  })
  .refine((v) => v.key_type !== 'secret' || v.scopes.length > 0, {
    message: 'Pick at least one scope',
    path: ['scopes'],
  })

type CreateFormValues = z.infer<typeof createSchema>

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
    resolver: zodResolver(createSchema),
    defaultValues: { name: '', key_type: 'secret', scopes: [] },
  })

  const keyType = form.watch('key_type')

  async function onSubmit(values: CreateFormValues) {
    const params: ApiKeyCreateParams = {
      name: values.name,
      key_type: values.key_type,
      scopes: values.key_type === 'secret' ? values.scopes : undefined,
    }
    try {
      const key = await createMutation.mutateAsync(params)
      toast.success(t('admin.messages.key_created'))
      form.reset({ name: '', key_type: 'secret', scopes: [] })
      onCreated(key)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : 'Failed to create key')
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset({ name: '', key_type: 'secret', scopes: [] })
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
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <Field>
              <FieldLabel htmlFor="api-key-name">{t('admin.fields.api_key.name.label')}</FieldLabel>
              <Input
                id="api-key-name"
                autoFocus
                placeholder={t('admin.fields.api_key.name.placeholder')}
                aria-invalid={!!form.formState.errors.name || undefined}
                {...form.register('name')}
              />
              <FieldError errors={[form.formState.errors.name]} />
            </Field>

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
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Creating…' : 'Create key'}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
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

function ScopePicker({ value, onChange }: { value: string[]; onChange: (next: string[]) => void }) {
  const { t } = useTranslation()
  const hasWriteAll = value.includes('write_all')
  const hasReadAll = value.includes('read_all')

  function toggleScope(scope: string) {
    onChange(value.includes(scope) ? value.filter((v) => v !== scope) : [...value, scope])
  }

  function setAllRead(checked: boolean) {
    let next = value.filter((v) => v !== 'read_all' && !v.startsWith('read_'))
    if (checked) next = [...next, 'read_all']
    onChange(next)
  }

  function setAllWrite(checked: boolean) {
    let next = value.filter((v) => v !== 'write_all' && !v.startsWith('write_'))
    if (checked) next = [...next, 'write_all']
    onChange(next)
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border">
      {/* Quick access: write_all / read_all toggles. Selecting one blocks the
          per-resource grid because the catch-all already covers it. */}
      <div className="flex flex-col gap-2 border-b border-border bg-muted/30 p-3">
        <label htmlFor="scope-write-all" className="flex cursor-pointer items-center gap-2 text-sm">
          <Checkbox id="scope-write-all" checked={hasWriteAll} onCheckedChange={setAllWrite} />
          <span className="font-medium">{t('admin.api_keys.scope_picker.full_access_label')}</span>
          <span className="text-xs text-muted-foreground">— read + write on every resource</span>
        </label>
        <label htmlFor="scope-read-all" className="flex cursor-pointer items-center gap-2 text-sm">
          <Checkbox
            id="scope-read-all"
            checked={hasReadAll}
            onCheckedChange={setAllRead}
            disabled={hasWriteAll}
          />
          <span className="font-medium">{t('admin.api_keys.scope_picker.read_all_label')}</span>
          <span className="text-xs text-muted-foreground">— read on every resource</span>
        </label>
      </div>

      <div
        className={cn(
          'grid grid-cols-[1fr_auto_auto] gap-x-4 gap-y-2 p-3 text-sm',
          (hasWriteAll || hasReadAll) && 'pointer-events-none opacity-50',
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
              label={group.label}
              hasRead={hasRead}
              hasWrite={hasWrite}
              readOnly={group.readOnly}
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
  onToggleRead,
  onToggleWrite,
}: {
  label: string
  hasRead: boolean
  hasWrite: boolean
  readOnly?: boolean
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
        disabled={hasWrite}
        aria-label={t('admin.api_keys.scope_picker.read_aria', { resource: label })}
        className="justify-self-center"
      />
      {readOnly ? (
        <span className="text-xs text-muted-foreground justify-self-center">—</span>
      ) : (
        <Checkbox
          checked={hasWrite}
          onCheckedChange={onToggleWrite}
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
            {t('admin.api_keys.done')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
