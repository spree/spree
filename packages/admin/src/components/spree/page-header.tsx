import { CheckIcon, CopyIcon, EllipsisVerticalIcon, TrashIcon } from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { BackButton } from '@/components/back-button'
import { useConfirm } from '@/components/confirm-dialog'
import { Slot } from '@/components/spree/slot'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

/**
 * Resource-shaped value PageHeader inspects to wire the more-actions dropdown.
 * Anything not present is simply omitted — no errors, no required fields beyond `id`.
 */
export interface PageHeaderResource {
  id: string
  /** Display number for "Copy number". Used on orders. */
  number?: string | null
}

interface PageHeaderProps {
  /** Main title (left of any badges). */
  title: ReactNode
  /** Small text below or beside the title (updated_at badge, customer email, etc.). */
  subtitle?: ReactNode
  /** Back button target — passed to <BackButton fallback="..."/>. Omit for top-level pages. */
  backTo?: string
  /** Status badges rendered next to the title. Use <StatusBadge /> for consistency. */
  badges?: ReactNode
  /** Primary action buttons (rightmost, before the dropdown). Most pages use this for "Save". */
  actions?: ReactNode
  /**
   * Domain-specific items to render at the top of the more-actions dropdown
   * (e.g., Complete/Approve/Cancel on orders). Rendered above the
   * `page.actions_dropdown` slot and the auto-wired Copy ID / Delete items.
   */
  dropdownItems?: ReactNode
  /**
   * The resource being edited. When supplied, PageHeader renders the legacy
   * "more actions" dropdown (Copy ID, Copy number, Delete). When omitted, the
   * dropdown is only rendered if a plugin has registered into `page.actions_dropdown`.
   */
  resource?: PageHeaderResource
  /** Slot context name. Defaults to inferring from `resource` keys. Optional. */
  slotContext?: Record<string, unknown>
  /**
   * Called after the user confirms the auto-rendered Delete action.
   * When provided, the Delete item is enabled. The confirmation prompt is
   * fixed ("Are you sure? This action cannot be undone.") — pass `dropdownItems`
   * directly if you need a custom delete flow.
   */
  onDelete?: () => void | Promise<void>
  /** Override the destructive label ("Delete order", "Delete product", etc.). */
  deleteLabel?: string
}

/**
 * Top-of-page chrome: back button + title + badges + subtitle, with primary
 * actions and a more-actions dropdown on the right.
 *
 * Mirrors `spree/admin/app/views/spree/admin/shared/_content_header.html.erb`:
 * the legacy header yields `:page_title`, `:page_actions`, `:page_actions_dropdown`
 * via `content_for`. Here those become props + the `page.actions` and
 * `page.actions_dropdown` slots, so plugins extend without overriding.
 */
export function PageHeader({
  title,
  subtitle,
  backTo,
  badges,
  actions,
  dropdownItems,
  resource,
  slotContext,
  onDelete,
  deleteLabel = 'Delete',
}: PageHeaderProps) {
  const slotCtx = { ...slotContext, resource }
  const showDropdown = Boolean(resource || onDelete || dropdownItems)

  return (
    <header className="flex items-start gap-3">
      {backTo && <BackButton fallback={backTo} />}

      <div className="flex flex-1 flex-wrap items-center gap-x-3 gap-y-1">
        <h1 className="text-2xl font-medium leading-tight">{title}</h1>
        {badges}
        {subtitle && <span className="text-sm text-muted-foreground">{subtitle}</span>}
      </div>

      <div className="ml-auto flex items-center gap-2">
        <Slot name="page.actions" context={slotCtx} />
        {actions}
        {showDropdown && (
          <PageActionsDropdown
            resource={resource}
            slotContext={slotCtx}
            dropdownItems={dropdownItems}
            onDelete={onDelete}
            deleteLabel={deleteLabel}
          />
        )}
      </div>
    </header>
  )
}

// ---------------------------------------------------------------------------
// More-actions dropdown
// ---------------------------------------------------------------------------

interface PageActionsDropdownProps {
  resource?: PageHeaderResource
  slotContext: Record<string, unknown>
  dropdownItems?: ReactNode
  onDelete?: () => void | Promise<void>
  deleteLabel: string
}

function PageActionsDropdown({
  resource,
  slotContext,
  dropdownItems,
  onDelete,
  deleteLabel,
}: PageActionsDropdownProps) {
  const confirm = useConfirm()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button size="icon-sm" variant="outline" aria-label="More actions">
          <EllipsisVerticalIcon className="size-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {dropdownItems}
        <Slot name="page.actions_dropdown" context={slotContext} />

        {resource?.number && <CopyToClipboardItem label="Copy number" value={resource.number} />}
        {resource && <CopyToClipboardItem label="Copy ID" value={resource.id} />}

        {onDelete && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              variant="destructive"
              onClick={async () => {
                if (
                  await confirm({
                    message: 'Are you sure? This action cannot be undone.',
                    variant: 'destructive',
                    confirmLabel: deleteLabel,
                  })
                ) {
                  await onDelete()
                }
              }}
            >
              <TrashIcon className="size-4" />
              {deleteLabel}
            </DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

// ---------------------------------------------------------------------------
// Copy-to-clipboard menu item
// ---------------------------------------------------------------------------

function CopyToClipboardItem({ label, value }: { label: string; value: string }) {
  const [copied, setCopied] = useState(false)

  return (
    <DropdownMenuItem
      // Keep the menu open after click so the user sees the confirmation flash.
      closeOnClick={false}
      onClick={async (e) => {
        e.preventDefault()
        try {
          await navigator.clipboard.writeText(value)
          setCopied(true)
          setTimeout(() => setCopied(false), 1200)
        } catch {
          // Clipboard API can fail in insecure contexts; ignore silently.
        }
      }}
    >
      {copied ? <CheckIcon className="size-4" /> : <CopyIcon className="size-4" />}
      {copied ? 'Copied' : label}
    </DropdownMenuItem>
  )
}
