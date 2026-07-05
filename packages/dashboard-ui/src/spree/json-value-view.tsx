import { Link } from '@tanstack/react-router'
import JsonView from '@uiw/react-json-view'
import { vscodeTheme } from '@uiw/react-json-view/vscode'
import { cn } from '../lib/utils'

/**
 * Maps a string value (typically a prefixed ID like `or_abc123`) to an
 * in-app route. Returned `to` is a `<Link to>` template; `params` is the
 * positional-param map passed straight through. Return `null` for values
 * that aren't linkable.
 *
 * No built-in prefix conventions ship with this component —
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

export interface JsonValueViewProps {
  /** JSON-serializable data to render. */
  value: unknown
  /**
   * Collapse depth. `false` expands everything, `true` collapses everything,
   * a `number` collapses below that depth. Default `2`.
   */
  collapsed?: boolean | number
  /** Resolve prefixed-ID strings to in-app links. Omit for plain strings. */
  resolveLink?: JsonValueLinkResolver
  /** Class applied to the outer wrapper. The view always uses a dark theme so
   * give it a dark surface (e.g. `bg-zinc-950`) when embedding into a light
   * page; otherwise the syntax colours don't have enough contrast. */
  className?: string
  /** When true, renders no padding/background — useful when the parent already
   * owns the surface chrome (e.g. inside a `<Card>` with its own padding). */
  bare?: boolean
}

/**
 * Read-only JSON tree viewer with optional ID-to-link resolution. Built on
 * `@uiw/react-json-view` with a vscode-style theme. Pulls in ~30KB gzip of
 * dependencies, so consumers should lazy-load this component via
 * `React.lazy(() => import('@spree/dashboard-ui/spree/json-value-view'))`
 * if it isn't on the critical path.
 *
 * @example  Inline preview inside a Card
 *   <Card>
 *     <CardContent className="bg-zinc-950">
 *       <JsonValueView value={delivery.payload} bare />
 *     </CardContent>
 *   </Card>
 *
 * @example  Linked prefixed IDs
 *   <JsonValueView value={order} resolveLink={resolveSpreePrefixToRoute} />
 */
export function JsonValueView({
  value,
  collapsed = 2,
  resolveLink,
  className,
  bare = false,
}: JsonValueViewProps) {
  return (
    <div
      className={cn(
        'font-mono text-sm',
        // The vscode theme is dark — when the parent doesn't already paint a
        // dark background, paint one here so the syntax colors stay legible.
        !bare && 'bg-zinc-950 text-zinc-100 rounded-md p-3',
        className,
      )}
    >
      <JsonView
        value={value as object}
        style={{ ...vscodeTheme, '--w-rjv-background-color': 'transparent' } as React.CSSProperties}
        collapsed={collapsed}
        displayDataTypes={false}
        displayObjectSize
        enableClipboard
        shortenTextAfterLength={60}
        components={{
          value: ({ value: v, type, ...rest }) => (
            <ValueRenderer value={v} type={type} resolveLink={resolveLink} {...rest} />
          ),
        }}
      />
    </div>
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
