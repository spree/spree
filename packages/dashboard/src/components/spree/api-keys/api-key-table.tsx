import type { ApiKey } from '@spree/admin-sdk'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Popover,
  PopoverContent,
  PopoverTrigger,
  RelativeTime,
  RowActions,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  toastManager,
  useConfirm,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import { BanIcon, CheckIcon, CopyIcon, KeyRoundIcon, PencilIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useDeleteApiKey, useRevokeApiKey } from '../../../hooks/use-api-keys'

export function ApiKeyTable({
  title,
  description,
  keys,
  loading,
  showScopes,
  showChannel = false,
  emptyMessage,
  onEdit,
  channelName,
}: {
  title: string
  description: string
  keys: ApiKey[]
  loading: boolean
  showScopes: boolean
  showChannel?: boolean
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
          <Table roundedBottom>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.fields.name.label')}</TableHead>
                <TableHead>{t('admin.pages.settings.api_keys.table.key')}</TableHead>
                {showScopes && (
                  <TableHead>{t('admin.pages.settings.api_keys.table.scopes')}</TableHead>
                )}
                {showChannel && (
                  <TableHead>{t('admin.pages.settings.api_keys.table.channel')}</TableHead>
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
                  showChannel={showChannel}
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
  showChannel,
  channelName,
}: {
  apiKey: ApiKey
  showScopes: boolean
  showChannel: boolean
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
      toastManager.add({ type: 'success', title: t('admin.messages.key_revoked') })
    } catch (err) {
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.failed_to_revoke_key'),
      })
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
      toastManager.add({ type: 'success', title: t('admin.messages.key_deleted') })
    } catch (err) {
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.api_keys.errors.failed_to_delete'),
      })
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
      {showChannel && (
        <TableCell className="text-sm whitespace-nowrap">
          {boundChannelName ?? (
            <span className="text-muted-foreground">
              {t('admin.pages.settings.api_keys.table.all_channels')}
            </span>
          )}
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
