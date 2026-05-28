import {
  Button,
  cn,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import JsonView from '@uiw/react-json-view'
import { vscodeTheme } from '@uiw/react-json-view/vscode'
import {
  CheckIcon,
  ChevronDownIcon,
  ChevronRightIcon,
  CopyIcon,
  ExternalLinkIcon,
  Loader2Icon,
  RotateCcwIcon,
  XIcon,
} from 'lucide-react'
import type { ComponentProps } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Maps a string value (typically a prefixed ID like `or_abc123`) to an
 * in-app route. Returned `to` is a `<Link to>` template; `params` is the
 * positional-param map passed straight through. Return `null` for values
 * that aren't linkable.
 *
 * The drawer doesn't ship with any built-in prefix conventions —
 * `@spree/dashboard` provides Spree's `or`→orders / `prod`→products /
 * `cus`→customers mapping at the call site so dashboard-ui stays
 * Spree-vocabulary-free.
 */
export type JsonValueLinkResolver = (
  value: string,
) => { to: string; params: Record<string, string> } | null

const VALUE_TYPE_STYLES: Record<string, { color: string; format: (v: unknown) => string }> = {
  string: { color: 'text-emerald-300', format: (v) => `"${v}"` },
  number: { color: 'text-amber-300', format: String },
  bigint: { color: 'text-amber-300', format: String },
  boolean: { color: 'text-purple-300', format: String },
}

export interface JsonPreviewDrawerProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Display title shown in the drawer header. Default "JSON". */
  title?: string
  /**
   * Fetcher that returns the resource JSON. Called every time the drawer
   * opens (so it always shows the latest server state — it's a debug tool)
   * and every time the user clicks the refresh button. The drawer manages
   * its own loading/error state internally; no react-query is involved.
   */
  fetch: () => Promise<unknown>
  /**
   * Resource path the JSON came from, e.g. `'/api/v3/admin/orders/or_xyz'`.
   * Shown in the toolbar and used as the "Open raw" target.
   */
  endpoint?: string
  /**
   * Turn string values (typically prefixed IDs) into clickable links to
   * other admin pages. Omit to render every string as inert text — the
   * default for plugin authors who haven't wired up their own ID→route
   * convention.
   */
  resolveLink?: JsonValueLinkResolver
}

export function JsonPreviewDrawer({
  open,
  onOpenChange,
  title = 'JSON',
  fetch,
  endpoint,
  resolveLink,
}: JsonPreviewDrawerProps) {
  const { t } = useTranslation()
  const [data, setData] = useState<unknown>(undefined)
  const [error, setError] = useState<Error | null>(null)
  const [isFetching, setIsFetching] = useState(false)
  // True only on the first load of an opened session — `isFetching` covers
  // subsequent refetches and animates the spinner button without blanking
  // the previously rendered JSON.
  const isLoading = isFetching && data === undefined && error === null

  // Refetch on every open + manual refresh. The drawer is a debug tool, so
  // staleness would be worse than the extra request. Re-fetching is gated on
  // `open` + the explicit refetch button below; a new `fetch` identity on
  // every render would otherwise loop.
  // biome-ignore lint/correctness/useExhaustiveDependencies: see above
  useEffect(() => {
    if (!open) return
    let cancelled = false
    setIsFetching(true)
    setError(null)
    fetch()
      .then((result) => {
        if (cancelled) return
        setData(result)
      })
      .catch((err) => {
        if (cancelled) return
        setError(err instanceof Error ? err : new Error(String(err)))
      })
      .finally(() => {
        if (cancelled) return
        setIsFetching(false)
      })
    return () => {
      cancelled = true
    }
  }, [open])

  const refetch = () => {
    setIsFetching(true)
    setError(null)
    fetch()
      .then(setData)
      .catch((err) => setError(err instanceof Error ? err : new Error(String(err))))
      .finally(() => setIsFetching(false))
  }

  const [collapsed, setCollapsed] = useState<boolean | number>(2)
  const { copied: copiedAll, copy } = useCopyToClipboard()

  const formatted = useMemo(() => (data ? JSON.stringify(data, null, 2) : ''), [data])

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="right"
        showCloseButton={false}
        className="w-full sm:max-w-2xl bg-zinc-950 text-zinc-100 border-zinc-800 overflow-hidden"
      >
        <SheetHeader className="border-b border-zinc-800 bg-zinc-950 text-zinc-100 rounded-t-xl">
          <SheetTitle className="text-zinc-100 font-mono text-base">{title}</SheetTitle>
          {endpoint && (
            <SheetDescription className="text-zinc-400 font-mono text-xs">
              GET {endpoint}
            </SheetDescription>
          )}
          <ToolbarButton
            size="icon-xs"
            className="absolute top-3 right-3"
            onClick={() => onOpenChange(false)}
            aria-label={t('admin.actions.close')}
          >
            <XIcon className="size-4" />
          </ToolbarButton>
        </SheetHeader>

        <div className="flex items-center gap-1 border-b border-zinc-800 px-3 py-2 text-xs">
          <ToolbarButton
            size="icon-xs"
            onClick={() => setCollapsed(false)}
            aria-label={t('admin.a11y.expand_all')}
            title={t('admin.a11y.expand_all')}
          >
            <ChevronDownIcon className="size-4" />
          </ToolbarButton>
          <ToolbarButton
            size="icon-xs"
            onClick={() => setCollapsed(true)}
            aria-label={t('admin.a11y.collapse_all')}
            title={t('admin.a11y.collapse_all')}
          >
            <ChevronRightIcon className="size-4" />
          </ToolbarButton>
          <DepthControl value={collapsed} onChange={setCollapsed} />

          <span className="ml-auto inline-flex items-center gap-1">
            <ToolbarButton size="xs" onClick={() => formatted && copy(formatted)} disabled={!data}>
              {copiedAll ? <CheckIcon className="size-3.5" /> : <CopyIcon className="size-3.5" />}
              {copiedAll ? 'Copied' : 'Copy all'}
            </ToolbarButton>
            <ToolbarButton
              size="icon-xs"
              onClick={() => refetch()}
              aria-label={t('admin.a11y.refetch')}
              title={t('admin.a11y.refetch')}
              disabled={isFetching}
            >
              {isFetching ? (
                <Loader2Icon className="size-3.5 animate-spin" />
              ) : (
                <RotateCcwIcon className="size-3.5" />
              )}
            </ToolbarButton>
            {endpoint && (
              <a
                href={endpoint}
                target="_blank"
                rel="noreferrer noopener"
                className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-100 transition-colors"
                title="Open raw response"
              >
                <ExternalLinkIcon className="size-3.5" />
                Raw
              </a>
            )}
          </span>
        </div>

        <div className="themed-scrollbar flex-1 overflow-auto p-4 font-mono text-sm">
          {isLoading ? (
            <p className="text-zinc-500">Loading…</p>
          ) : error ? (
            <p className="text-red-400">Failed to load: {error.message}</p>
          ) : data ? (
            <JsonView
              value={data as object}
              style={
                { ...vscodeTheme, '--w-rjv-background-color': 'transparent' } as React.CSSProperties
              }
              collapsed={collapsed}
              displayDataTypes={false}
              displayObjectSize
              enableClipboard
              shortenTextAfterLength={60}
              components={{
                value: ({ value, type, ...rest }) => (
                  <ValueRenderer value={value} type={type} resolveLink={resolveLink} {...rest} />
                ),
              }}
            />
          ) : null}
        </div>
      </SheetContent>
    </Sheet>
  )
}

function ToolbarButton({ className, ...props }: ComponentProps<typeof Button>) {
  return (
    <Button
      type="button"
      variant="ghost"
      className={cn('text-zinc-400 hover:bg-zinc-800 hover:text-zinc-100', className)}
      {...props}
    />
  )
}

function DepthControl({
  value,
  onChange,
}: {
  value: boolean | number
  onChange: (next: boolean | number) => void
}) {
  const current = typeof value === 'number' ? `${value}` : value === true ? 'all' : 'open'
  return (
    <select
      value={current}
      onChange={(e) => {
        const v = e.target.value
        if (v === 'all') onChange(true)
        else if (v === 'open') onChange(false)
        else onChange(Number(v))
      }}
      className="ml-1 bg-zinc-900 border border-zinc-700 rounded px-1.5 py-1 text-xs text-zinc-300 hover:bg-zinc-800 focus:outline-none focus:ring-1 focus:ring-zinc-600"
      title="Collapse depth"
    >
      <option value="open">Expand all</option>
      <option value="1">Depth 1</option>
      <option value="2">Depth 2</option>
      <option value="3">Depth 3</option>
      <option value="all">Collapse all</option>
    </select>
  )
}

interface ValueRendererProps {
  value: unknown
  type: string
  resolveLink?: JsonValueLinkResolver
}

function ValueRenderer({
  value,
  type,
  resolveLink,
  ...rest
}: ValueRendererProps & React.HTMLAttributes<HTMLSpanElement>) {
  if (type === 'string' && typeof value === 'string' && resolveLink) {
    const resolved = resolveLink(value)
    if (resolved) {
      return (
        <span {...rest} className="text-emerald-300">
          "
          <Link
            to={resolved.to}
            params={resolved.params}
            className="text-emerald-300 underline decoration-emerald-700 hover:decoration-emerald-300 transition-colors"
            onClick={(e) => e.stopPropagation()}
          >
            {value}
          </Link>
          "
        </span>
      )
    }
  }
  return <JsonValueSpan value={value} type={type} {...rest} />
}

function JsonValueSpan({
  value,
  type,
  ...rest
}: {
  value: unknown
  type: string
} & React.HTMLAttributes<HTMLSpanElement>) {
  const style = value === null ? null : VALUE_TYPE_STYLES[type]
  const color = value === null ? 'text-zinc-500' : (style?.color ?? 'text-zinc-300')
  const display = value === null ? 'null' : style ? style.format(value) : String(value)
  return (
    <span {...rest} className={color}>
      {display}
    </span>
  )
}
