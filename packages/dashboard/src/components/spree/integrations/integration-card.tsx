import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Button,
  Card,
  CardContent,
  CardFooter,
  cn,
  Switch,
} from '@spree/dashboard-ui'
import { ExternalLinkIcon } from '@spree/dashboard-ui/icons'
import { type ReactNode, useEffect, useRef, useState } from 'react'

export type IntegrationCardStatus = 'active' | 'inactive' | 'not_connected'

/**
 * One tile of the integrations gallery. Shared by connected services and
 * payment providers so both read as the same kind of thing: a logo, its
 * state, a switch to turn it on or off, and one action.
 */
export function IntegrationCard({
  name,
  logoUrl,
  status,
  statusLabels,
  description,
  tags,
  toggle,
  docsUrl,
  docsLabel,
  actionLabel,
  onAction,
}: {
  name: string
  logoUrl?: string | null
  status: IntegrationCardStatus
  /** Wording per state — the card picks one, following the switch while a save is in flight. */
  statusLabels: Record<IntegrationCardStatus, string>
  description?: string
  tags?: ReactNode
  toggle?: {
    checked: boolean
    disabled?: boolean
    label: string
    /**
     * Return the save's promise, resolving to the value the server kept, and
     * the switch moves at once and settles when it lands — flipping back if
     * the save fails. Return nothing when the switch opens a form instead.
     */
    onCheckedChange: (checked: boolean) => Promise<boolean> | undefined
  }
  /** Setup guide, opened in a new tab. Only absolute http(s) URLs are linked. */
  docsUrl?: string | null
  docsLabel: string
  actionLabel: string
  onAction: () => void
}) {
  // The value the merchant just chose, shown until the saved record agrees.
  const [optimisticChecked, setOptimisticChecked] = useState<boolean | null>(null)
  // Mirrors `saveInFlight` for rendering: while a save is open the record can
  // still hold the value from before it, which must not end the optimistic one.
  const [saving, setSaving] = useState(false)
  const savedChecked = toggle?.checked

  useEffect(() => {
    if (!saving && optimisticChecked !== null && savedChecked === optimisticChecked) {
      setOptimisticChecked(null)
    }
  }, [saving, savedChecked, optimisticChecked])

  const displayedStatus: IntegrationCardStatus =
    optimisticChecked === null ? status : optimisticChecked ? 'active' : 'inactive'

  // One save at a time, so saves cannot land out of order. Clicks made while
  // one is in flight only move the switch; the latest of them is saved when
  // it settles, unless the server already holds that value.
  const saveInFlight = useRef(false)
  const queuedChecked = useRef<boolean | null>(null)

  function save(checked: boolean, request: Promise<boolean>) {
    saveInFlight.current = true
    setSaving(true)
    request.then(
      (kept) => settle(checked, kept),
      () => settle(checked, null),
    )
  }

  function settle(requested: boolean, kept: boolean | null) {
    saveInFlight.current = false
    setSaving(false)
    const next = queuedChecked.current
    queuedChecked.current = null
    if (next !== null && next !== kept) {
      const request = toggle?.onCheckedChange(next)
      if (request) return save(next, request)
    }
    if (next === null && kept === requested) return
    if (next === null || next !== kept) setOptimisticChecked(null)
  }

  function handleCheckedChange(checked: boolean) {
    if (saveInFlight.current) {
      queuedChecked.current = checked
      setOptimisticChecked(checked)
      return
    }
    const request = toggle?.onCheckedChange(checked)
    if (!request) return
    setOptimisticChecked(checked)
    save(checked, request)
  }

  return (
    <Card>
      <CardContent className="flex flex-1 flex-col gap-3 p-4">
        <div className="flex items-start gap-3">
          <IntegrationLogo name={name} logoUrl={logoUrl ?? null} />
          <div className="flex min-w-0 flex-1 flex-col gap-0.5">
            <span className="truncate font-semibold text-sm">{name}</span>
            <span className="flex items-center gap-1.5 text-muted-foreground text-xs">
              <span
                aria-hidden
                className={cn(
                  'size-1.5 shrink-0 rounded-full',
                  displayedStatus === 'active' && 'bg-success',
                  displayedStatus === 'inactive' && 'bg-warning',
                  displayedStatus === 'not_connected' && 'bg-muted-foreground/40',
                )}
              />
              {statusLabels[displayedStatus]}
            </span>
          </div>
          {toggle && (
            <Switch
              checked={optimisticChecked ?? toggle.checked}
              disabled={toggle.disabled}
              aria-label={toggle.label}
              onCheckedChange={handleCheckedChange}
            />
          )}
        </div>
        {description && <p className="line-clamp-2 text-muted-foreground text-sm">{description}</p>}
        {tags && <div className="mt-auto flex flex-wrap gap-1.5">{tags}</div>}
      </CardContent>
      <CardFooter className="justify-between gap-2 bg-muted/40 px-4 py-2">
        {docsUrl && /^https?:\/\//.test(docsUrl) ? (
          <a
            href={docsUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="link inline-flex items-center gap-1 text-sm"
          >
            {docsLabel}
            <ExternalLinkIcon className="size-3.5" />
          </a>
        ) : (
          <span />
        )}
        <Button
          size="sm"
          variant={status === 'not_connected' ? 'default' : 'ghost'}
          onClick={onAction}
        >
          {actionLabel}
        </Button>
      </CardFooter>
    </Card>
  )
}

// Gem-declared logo (hosted URL or data URI); the Avatar compound shows the
// initial-letter fallback until the image loads, covering unset and
// unreachable URLs alike — same pattern as the store switcher.
function IntegrationLogo({ name, logoUrl }: { name: string; logoUrl: string | null }) {
  return (
    <Avatar className="size-10 shrink-0 rounded-lg bg-background p-1.5 after:rounded-lg after:border-border-subtle">
      {logoUrl && <AvatarImage src={logoUrl} className="rounded-none object-contain" />}
      <AvatarFallback className="rounded-md bg-transparent font-semibold">
        {name.charAt(0).toUpperCase()}
      </AvatarFallback>
    </Avatar>
  )
}
