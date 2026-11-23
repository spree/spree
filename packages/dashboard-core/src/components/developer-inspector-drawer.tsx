import {
  Badge,
  Button,
  CopyToClipboardButton,
  cn,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetTitle,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '@spree/dashboard-ui'
import { BugIcon, InfoIcon, Trash2Icon, XIcon } from '@spree/dashboard-ui/icons'
// Deep import keeps the JSON viewer out of the dashboard-ui barrel's chunk.
import { JsonValueView } from '@spree/dashboard-ui/spree/json-value-view'
import { Link } from '@tanstack/react-router'
import { memo, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  clearDeveloperInspector,
  type DeveloperInspectorEntry,
  isFailedEntry,
} from '../lib/developer-inspector'
import { entryToCurl, entryToSdkCall } from '../lib/request-snippets'
import {
  useDeveloperInspectorEntries,
  useOptionalDeveloperInspector,
} from '../providers/developer-inspector-provider'
import { useJsonLinkResolver } from '../providers/json-link-resolver-provider'

export interface DeveloperInspectorDrawerProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  systemInfoPath?: string
}

export function DeveloperInspectorDrawer({
  open,
  onOpenChange,
  systemInfoPath,
}: DeveloperInspectorDrawerProps) {
  const { t } = useTranslation()
  const entries = useDeveloperInspectorEntries()
  const errors = entries.filter(isFailedEntry)
  const sendFeedback = useOptionalDeveloperInspector()?.sendFeedback
  const [selectedId, setSelectedId] = useState<number | null>(null)

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="bottom"
        showCloseButton={false}
        // Always dark, like browser devtools. The height uses the side variant
        // so it replaces the sheet's own `data-[side=bottom]:h-auto`.
        className="dark overflow-hidden rounded-t-2xl data-[side=bottom]:h-[min(75dvh,720px)]"
      >
        <div className="flex shrink-0 items-start gap-3 border-b border-border-subtle px-4 py-3">
          <div className="min-w-0 flex-1">
            <SheetTitle>{t('admin.components.developer_inspector.title')}</SheetTitle>
            <SheetDescription className="text-xs">
              {t('admin.components.developer_inspector.description')}
            </SheetDescription>
          </div>
          {sendFeedback && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                onOpenChange(false)
                sendFeedback('bug')
              }}
            >
              <BugIcon />
              {t('admin.account.report_issue')}
            </Button>
          )}
          {systemInfoPath && (
            <Button variant="ghost" size="sm" asChild>
              <Link to={systemInfoPath as never} onClick={() => onOpenChange(false)}>
                <InfoIcon />
                {t('admin.components.developer_inspector.system_info')}
              </Link>
            </Button>
          )}
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              clearDeveloperInspector()
              setSelectedId(null)
            }}
            disabled={entries.length === 0}
          >
            <Trash2Icon />
            {t('admin.components.developer_inspector.clear')}
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => onOpenChange(false)}
            aria-label={t('admin.actions.close')}
          >
            <XIcon />
          </Button>
        </div>

        <Tabs defaultValue="requests" className="min-h-0 flex-1 gap-0">
          <div className="shrink-0 px-4 pt-3">
            <TabsList>
              <TabsTrigger value="requests" count={entries.length}>
                {t('admin.components.developer_inspector.tabs.requests')}
              </TabsTrigger>
              <TabsTrigger value="errors" count={errors.length}>
                {t('admin.components.developer_inspector.tabs.errors')}
              </TabsTrigger>
            </TabsList>
          </div>
          <TabsContent value="requests" className="min-h-0 overflow-hidden">
            <RequestsPanel
              entries={entries}
              selectedId={selectedId}
              onSelect={setSelectedId}
              emptyLabel={t('admin.components.developer_inspector.empty_requests')}
            />
          </TabsContent>
          <TabsContent value="errors" className="min-h-0 overflow-hidden">
            <RequestsPanel
              entries={errors}
              selectedId={selectedId}
              onSelect={setSelectedId}
              emptyLabel={t('admin.components.developer_inspector.empty_errors')}
              showErrorCode
            />
          </TabsContent>
        </Tabs>
      </SheetContent>
    </Sheet>
  )
}

function RequestsPanel({
  entries,
  selectedId,
  onSelect,
  emptyLabel,
  showErrorCode = false,
}: {
  entries: DeveloperInspectorEntry[]
  selectedId: number | null
  onSelect: (id: number) => void
  emptyLabel: string
  showErrorCode?: boolean
}) {
  const { t } = useTranslation()
  const selected = entries.find((entry) => entry.id === selectedId)

  if (entries.length === 0) {
    return <p className="p-4 text-muted-foreground">{emptyLabel}</p>
  }

  return (
    <div className="grid h-full min-h-0 grid-rows-[minmax(0,1fr)_minmax(0,1fr)] md:grid-cols-[minmax(0,2fr)_minmax(0,3fr)] md:grid-rows-1">
      <ul className="themed-scrollbar min-h-0 overflow-auto border-border-subtle border-b p-2 md:border-r md:border-b-0">
        {entries.map((entry) => (
          <li key={entry.id}>
            <button
              type="button"
              onClick={() => onSelect(entry.id)}
              aria-current={entry.id === selectedId || undefined}
              className={cn(
                'grid w-full grid-cols-[3.5rem_3rem_minmax(0,1fr)_auto] items-center gap-2 rounded-md px-2 py-1.5 text-left font-mono text-xs transition-colors duration-100 hover:bg-accent',
                entry.id === selectedId && 'bg-accent',
              )}
            >
              <span className="font-medium">{entry.method}</span>
              <StatusBadge entry={entry} />
              <span className="min-w-0">
                <span className="block truncate">{entry.path}</span>
                <span className="block truncate text-muted-foreground">
                  {showErrorCode && entry.errorCode ? `${entry.errorCode} · ` : ''}
                  {entry.requestId ?? '—'}
                </span>
              </span>
              <span className="text-muted-foreground tabular-nums">
                {t('admin.components.developer_inspector.duration_ms', { value: entry.durationMs })}
              </span>
            </button>
          </li>
        ))}
      </ul>
      <div className="themed-scrollbar min-h-0 overflow-auto p-4">
        {selected ? (
          <RequestDetail entry={selected} />
        ) : (
          <p className="text-muted-foreground">
            {t('admin.components.developer_inspector.select_request')}
          </p>
        )}
      </div>
    </div>
  )
}

function StatusBadge({ entry }: { entry: DeveloperInspectorEntry }) {
  const { t } = useTranslation()
  if (entry.status === null) {
    return (
      <Badge variant="destructive">{t('admin.components.developer_inspector.network_error')}</Badge>
    )
  }
  const variant = entry.status >= 400 ? 'destructive' : 'success'
  return <Badge variant={variant}>{entry.status}</Badge>
}

// Memoised: the drawer re-renders on every recorded request, and an entry
// never changes once recorded.
const RequestDetail = memo(function RequestDetail({ entry }: { entry: DeveloperInspectorEntry }) {
  const { t } = useTranslation()
  const copied = t('admin.components.developer_inspector.copied')
  const hasQuery = !!entry.query && Object.keys(entry.query).length > 0
  const copies = useMemo(() => {
    const candidates: [string, string | null][] = [
      ['copy_curl', entryToCurl(entry)],
      ['copy_sdk', entryToSdkCall(entry)],
      [
        'copy_response',
        entry.responseBody === undefined ? null : JSON.stringify(entry.responseBody, null, 2),
      ],
      ['copy_request_id', entry.requestId],
    ]
    return candidates.flatMap(([key, value]) => (value == null ? [] : [{ key, value }]))
  }, [entry])

  return (
    <div className="flex flex-col gap-4">
      <p className="break-all font-mono text-xs">
        <span className="font-medium">{entry.method}</span> {entry.url}
      </p>

      <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-1 text-xs">
        <dt className="text-muted-foreground">
          {t('admin.components.developer_inspector.status')}
        </dt>
        <dd>
          <StatusBadge entry={entry} />
        </dd>
        <dt className="text-muted-foreground">
          {t('admin.components.developer_inspector.duration')}
        </dt>
        <dd className="tabular-nums">
          {t('admin.components.developer_inspector.duration_ms', { value: entry.durationMs })}
        </dd>
        <dt className="text-muted-foreground">
          {t('admin.components.developer_inspector.request_id')}
        </dt>
        <dd className="break-all font-mono" data-testid="developer-inspector-request-id">
          {entry.requestId ?? '—'}
        </dd>
        {entry.errorCode && (
          <>
            <dt className="text-muted-foreground">
              {t('admin.components.developer_inspector.error_code')}
            </dt>
            <dd className="break-all font-mono">
              {entry.errorCode}
              {entry.errorMessage && (
                <span className="block font-sans text-muted-foreground">{entry.errorMessage}</span>
              )}
            </dd>
          </>
        )}
      </dl>

      <div className="flex flex-wrap gap-2">
        {copies.map(({ key, value }) => (
          <CopyToClipboardButton
            key={key}
            value={value}
            aria-label={t(`admin.components.developer_inspector.${key}`)}
            label={t(`admin.components.developer_inspector.${key}`)}
            copiedLabel={copied}
            size="sm"
            variant="outline"
          />
        ))}
      </div>

      {hasQuery && (
        <BodySection title={t('admin.components.developer_inspector.query')} value={entry.query} />
      )}
      {entry.requestBody !== undefined && entry.requestBody !== null && (
        <BodySection
          title={t('admin.components.developer_inspector.request_body')}
          value={entry.requestBody}
        />
      )}
      <BodySection
        title={t('admin.components.developer_inspector.response_body')}
        value={entry.responseBody}
      />
    </div>
  )
})

function BodySection({ title, value }: { title: string; value: unknown }) {
  const { t } = useTranslation()
  const resolveLink = useJsonLinkResolver()
  return (
    <section className="flex flex-col gap-1.5">
      <h3 className="font-medium text-muted-foreground text-xs">{title}</h3>
      {value !== null && typeof value === 'object' ? (
        <JsonValueView value={value} collapsed={1} resolveLink={resolveLink} />
      ) : (
        <p className="rounded-md bg-zinc-950 p-3 font-mono text-xs text-zinc-100">
          {value === undefined ? t('admin.components.developer_inspector.no_body') : String(value)}
        </p>
      )}
    </section>
  )
}
