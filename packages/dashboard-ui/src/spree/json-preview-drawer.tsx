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
import { type JsonValueLinkResolver, JsonValueView } from './json-value-view'

// Re-export so existing imports of `JsonValueLinkResolver` from this module
// keep working without touching call sites.
export type { JsonValueLinkResolver } from './json-value-view'

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

  // Refetch on every open + when the resource being inspected changes + on
  // manual refresh. The drawer is a debug tool, so staleness would be worse
  // than the extra request. `endpoint` stands in for "which resource is this
  // drawer pointing at" since it's a stable per-resource string; `fetch`
  // intentionally isn't in the deps because a fresh inline-arrow identity
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
  }, [open, endpoint])

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
              {copiedAll
                ? t('admin.components.json_preview_drawer.copied')
                : t('admin.components.json_preview_drawer.copy_all')}
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
                title={t('admin.components.json_preview_drawer.open_raw')}
              >
                <ExternalLinkIcon className="size-3.5" />
                {t('admin.components.json_preview_drawer.raw')}
              </a>
            )}
          </span>
        </div>

        <div className="themed-scrollbar flex-1 overflow-auto p-4 font-mono text-sm">
          {isLoading ? (
            <p className="text-zinc-500">{t('admin.common.loading')}</p>
          ) : error ? (
            <p className="text-red-400">
              {t('admin.components.json_preview_drawer.failed_to_load', { message: error.message })}
            </p>
          ) : data !== undefined ? (
            // The drawer paints its own dark surface around the renderer
            // (Sheet content + toolbar), so the view itself runs in `bare`
            // mode — no extra padding/background.
            <JsonValueView value={data} collapsed={collapsed} resolveLink={resolveLink} bare />
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
  const { t } = useTranslation()
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
      title={t('admin.components.json_preview_drawer.collapse_depth')}
    >
      <option value="open">{t('admin.a11y.expand_all')}</option>
      <option value="1">{t('admin.components.json_preview_drawer.depth', { level: 1 })}</option>
      <option value="2">{t('admin.components.json_preview_drawer.depth', { level: 2 })}</option>
      <option value="3">{t('admin.components.json_preview_drawer.depth', { level: 3 })}</option>
      <option value="all">{t('admin.a11y.collapse_all')}</option>
    </select>
  )
}
