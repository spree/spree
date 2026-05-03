import { useQuery } from '@tanstack/react-query'
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
import { useMemo, useState } from 'react'
import { Button } from '@/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { useCopyToClipboard } from '@/hooks/use-copy-to-clipboard'
import { cn } from '@/lib/utils'

const PREFIX_DESTINATIONS: Record<string, { route: string; param: string }> = {
  or: { route: '/$storeId/orders/$orderId', param: 'orderId' },
  prod: { route: '/$storeId/products/$productId', param: 'productId' },
  cus: { route: '/$storeId/customers/$customerId', param: 'customerId' },
}

const PREFIXED_ID_RE = /^([a-z]+(?:_[a-z]+)*)_([A-Za-z0-9]{6,})$/

function parsePrefixedId(value: unknown): { route: string; param: string } | null {
  if (typeof value !== 'string') return null
  const match = PREFIXED_ID_RE.exec(value)
  return match ? (PREFIX_DESTINATIONS[match[1]] ?? null) : null
}

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
   * React-Query key for the fetch. Each open refetches (`staleTime: 0`) — the
   * drawer is a debug tool, so it always shows the latest server state.
   */
  queryKey: readonly unknown[]
  /** Fetcher that returns the resource JSON. Called inside `useQuery`. */
  queryFn: () => Promise<unknown>
  /**
   * Resource path the JSON came from, e.g. `'/api/v3/admin/orders/or_xyz'`.
   * Shown in the toolbar and used as the "Open raw" target.
   */
  endpoint?: string
  /** Store ID for prefixed-ID links to other admin pages. */
  storeId: string
}

export function JsonPreviewDrawer({
  open,
  onOpenChange,
  title = 'JSON',
  queryKey,
  queryFn,
  endpoint,
  storeId,
}: JsonPreviewDrawerProps) {
  const { data, isLoading, isFetching, error, refetch } = useQuery({
    queryKey,
    queryFn,
    enabled: open,
    staleTime: 0,
  })

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
            aria-label="Close"
          >
            <XIcon className="size-4" />
          </ToolbarButton>
        </SheetHeader>

        <div className="flex items-center gap-1 border-b border-zinc-800 px-3 py-2 text-xs">
          <ToolbarButton
            size="icon-xs"
            onClick={() => setCollapsed(false)}
            aria-label="Expand all"
            title="Expand all"
          >
            <ChevronDownIcon className="size-4" />
          </ToolbarButton>
          <ToolbarButton
            size="icon-xs"
            onClick={() => setCollapsed(true)}
            aria-label="Collapse all"
            title="Collapse all"
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
              aria-label="Refetch"
              title="Refetch"
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

        <div className="flex-1 overflow-auto p-4 font-mono text-sm">
          {isLoading ? (
            <p className="text-zinc-500">Loading…</p>
          ) : error ? (
            <p className="text-red-400">
              Failed to load: {error instanceof Error ? error.message : String(error)}
            </p>
          ) : data ? (
            <JsonView
              value={data as object}
              style={vscodeTheme}
              collapsed={collapsed}
              displayDataTypes={false}
              displayObjectSize
              enableClipboard
              shortenTextAfterLength={60}
              components={{
                value: ({ value, type, ...rest }) => (
                  <ValueRenderer value={value} type={type} storeId={storeId} {...rest} />
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
  storeId: string
}

function ValueRenderer({
  value,
  type,
  storeId,
  ...rest
}: ValueRendererProps & React.HTMLAttributes<HTMLSpanElement>) {
  if (type === 'string') {
    const parsed = parsePrefixedId(value)
    if (parsed) {
      return (
        <span {...rest} className="text-emerald-300">
          "
          <Link
            to={parsed.route}
            params={{ storeId, [parsed.param]: value as string }}
            className="text-emerald-300 underline decoration-emerald-700 hover:decoration-emerald-300 transition-colors"
            onClick={(e) => e.stopPropagation()}
          >
            {String(value)}
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
