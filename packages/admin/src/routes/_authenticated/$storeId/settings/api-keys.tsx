import { zodResolver } from '@hookform/resolvers/zod'
import type { ApiKey, ApiKeyCreateParams } from '@spree/admin-sdk'
import { createFileRoute } from '@tanstack/react-router'
import {
  AlertTriangleIcon,
  CheckIcon,
  CopyIcon,
  KeyRoundIcon,
  MoreHorizontalIcon,
  PlusIcon,
} from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { EmptyState } from '@/components/spree/empty-state'
import { PageHeader } from '@/components/spree/page-header'
import { RelativeTime } from '@/components/spree/relative-time'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/data-table'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Field, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import { useApiKeys, useCreateApiKey, useDeleteApiKey, useRevokeApiKey } from '@/hooks/use-api-keys'
import { useCopyToClipboard } from '@/hooks/use-copy-to-clipboard'
import { cn } from '@/lib/utils'

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
  const { data, isLoading } = useApiKeys()
  const [createOpen, setCreateOpen] = useState(false)
  const [tokenReveal, setTokenReveal] = useState<ApiKey | null>(null)

  const keys = data?.data ?? []
  const publishable = keys.filter((k) => k.key_type === 'publishable')
  const secret = keys.filter((k) => k.key_type === 'secret')

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="API keys"
        subtitle="Publishable and secret keys for the Storefront and Admin APIs."
        actions={
          <Button size="sm" onClick={() => setCreateOpen(true)}>
            <PlusIcon className="size-4" />
            Create key
          </Button>
        }
      />

      <ApiKeyTable
        title="Publishable"
        description="Used by your storefront. Safe to expose in client-side code."
        keys={publishable}
        loading={isLoading}
        showScopes={false}
      />

      <ApiKeyTable
        title="Secret"
        description="Server-to-server only. Never expose in client-side code."
        keys={secret}
        loading={isLoading}
        showScopes
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
}: {
  title: string
  description: string
  keys: ApiKey[]
  loading: boolean
  showScopes: boolean
}) {
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
          <EmptyState
            icon={<KeyRoundIcon />}
            title={`No ${title.toLowerCase()} keys yet`}
            description="Create one to get started."
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Token</TableHead>
                {showScopes && <TableHead>Scopes</TableHead>}
                <TableHead>Last used</TableHead>
                <TableHead>Created</TableHead>
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
      title: 'Revoke key?',
      message: `Future requests using ${apiKey.name} will fail. The key stays in the list (with a revoked badge) so you can audit it later.`,
      variant: 'destructive',
      confirmLabel: 'Revoke',
    })
    if (!ok) return

    try {
      await revokeMutation.mutateAsync(apiKey.id)
      toast.success('Key revoked')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to revoke key')
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: 'Delete key?',
      message: `${apiKey.name} will be permanently removed from this store. This can't be undone.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!ok) return

    try {
      await deleteMutation.mutateAsync(apiKey.id)
      toast.success('Key deleted')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to delete key')
    }
  }

  return (
    <TableRow className={cn(isRevoked && 'opacity-60')}>
      <TableCell>
        <div className="flex items-center gap-2">
          <span className="font-medium">{apiKey.name}</span>
          {isRevoked && <Badge variant="destructive">Revoked</Badge>}
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
              aria-label="Copy token"
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
          fallback={<span className="text-muted-foreground/60">Never</span>}
        />
      </TableCell>
      <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
        <RelativeTime iso={apiKey.created_at} />
        {apiKey.created_by_email && <div className="text-xs">by {apiKey.created_by_email}</div>}
      </TableCell>
      <TableCell className="text-right">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button size="icon-sm" variant="ghost" aria-label="Actions">
              <MoreHorizontalIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {!isRevoked && (
              <>
                <DropdownMenuItem onClick={handleRevoke}>Revoke key</DropdownMenuItem>
                <DropdownMenuSeparator />
              </>
            )}
            <DropdownMenuItem variant="destructive" onClick={handleDelete}>
              Delete key
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </TableCell>
    </TableRow>
  )
}

// Maximum number of scope chips rendered inline before collapsing the rest
// into a `+N` popover. Chosen so a typical row stays under one line at the
// usual table widths.
const SCOPE_PREVIEW_COUNT = 3

function ScopeList({ scopes }: { scopes: string[] }) {
  if (scopes.includes('write_all')) {
    return <Badge>Full access</Badge>
  }
  if (scopes.includes('read_all')) {
    return <Badge>Read all</Badge>
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
      toast.success('Key created')
      form.reset({ name: '', key_type: 'secret', scopes: [] })
      onCreated(key)
    } catch (err) {
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
          <SheetTitle>Create API key</SheetTitle>
          <SheetDescription>
            Secret keys are server-to-server only and limited to the scopes you pick. Publishable
            keys are for storefront/client-side use and have no scopes.
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          {/* `flex-1 overflow-y-auto` keeps the footer pinned while the body
              scrolls when the scope grid overflows. */}
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <Field>
              <FieldLabel htmlFor="key-name">Name</FieldLabel>
              <Input
                id="key-name"
                autoFocus
                placeholder="Backend integration, Storefront prod, …"
                {...form.register('name')}
                aria-invalid={!!form.formState.errors.name}
              />
              {form.formState.errors.name && (
                <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
              )}
            </Field>

            <Field>
              <FieldLabel>Type</FieldLabel>
              <Controller
                name="key_type"
                control={form.control}
                render={({ field }) => (
                  <div className="grid grid-cols-2 gap-2">
                    <KeyTypeOption
                      value="secret"
                      label="Secret"
                      description="Admin API · server-to-server"
                      selected={field.value === 'secret'}
                      onSelect={() => field.onChange('secret')}
                    />
                    <KeyTypeOption
                      value="publishable"
                      label="Publishable"
                      description="Storefront · safe to expose"
                      selected={field.value === 'publishable'}
                      onSelect={() => field.onChange('publishable')}
                    />
                  </div>
                )}
              />
            </Field>

            {keyType === 'secret' && (
              <Field>
                <FieldLabel>Scopes</FieldLabel>
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

function KeyTypeOption({
  label,
  description,
  selected,
  onSelect,
}: {
  value: 'publishable' | 'secret'
  label: string
  description: string
  selected: boolean
  onSelect: () => void
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        'flex flex-col items-start gap-1 rounded-lg border p-3 text-left transition-colors',
        selected
          ? 'border-blue-300 bg-blue-500/5 text-blue-600 dark:border-blue-600/75'
          : 'border-border hover:border-foreground/30',
      )}
    >
      <span className="font-medium">{label}</span>
      <span className="text-xs text-muted-foreground">{description}</span>
    </button>
  )
}

function ScopePicker({ value, onChange }: { value: string[]; onChange: (next: string[]) => void }) {
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
        <label className="flex cursor-pointer items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={hasWriteAll}
            onChange={(e) => setAllWrite(e.target.checked)}
            className="size-4 rounded border-border accent-primary"
          />
          <span className="font-medium">Full access (write_all)</span>
          <span className="text-xs text-muted-foreground">— read + write on every resource</span>
        </label>
        <label className="flex cursor-pointer items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={hasReadAll}
            onChange={(e) => setAllRead(e.target.checked)}
            disabled={hasWriteAll}
            className="size-4 rounded border-border accent-primary"
          />
          <span className="font-medium">Read all (read_all)</span>
          <span className="text-xs text-muted-foreground">— read on every resource</span>
        </label>
      </div>

      <div
        className={cn(
          'grid grid-cols-[1fr_auto_auto] gap-x-4 gap-y-2 p-3 text-sm',
          (hasWriteAll || hasReadAll) && 'pointer-events-none opacity-50',
        )}
      >
        <span className="font-medium text-muted-foreground">Resource</span>
        <span className="font-medium text-muted-foreground">Read</span>
        <span className="font-medium text-muted-foreground">Write</span>
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
  return (
    <>
      <span>{label}</span>
      <input
        type="checkbox"
        checked={hasRead}
        onChange={onToggleRead}
        // Checking write implies read; reflect that here so the UI doesn't
        // look out of sync with what the server will enforce.
        disabled={hasWrite}
        aria-label={`Read ${label}`}
        className="size-4 justify-self-center rounded border-border accent-primary"
      />
      {readOnly ? (
        <span className="text-xs text-muted-foreground justify-self-center">—</span>
      ) : (
        <input
          type="checkbox"
          checked={hasWrite}
          onChange={onToggleWrite}
          aria-label={`Write ${label}`}
          className="size-4 justify-self-center rounded border-border accent-primary"
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
  const { copied, copy } = useCopyToClipboard()

  return (
    <Dialog open={!!apiKey} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Save your secret key</DialogTitle>
          <DialogDescription>
            This is the only time we'll show you the full key. Store it in a password manager or
            your secret store now — if you lose it, you'll need to create a new one.
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-3">
          <div className="flex items-start gap-2 rounded-md border border-yellow-200 bg-yellow-50 p-3 text-sm text-yellow-900 dark:border-yellow-900/40 dark:bg-yellow-950/40 dark:text-yellow-200">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>
              Treat this key like a password. Anyone with it can act on your store via the Admin
              API.
            </span>
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
                {copied ? 'Copied' : 'Copy'}
              </Button>
            </div>
          )}
        </DialogBody>
        <DialogFooter>
          <Button size="sm" onClick={() => onOpenChange(false)}>
            Done
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
