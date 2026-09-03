import {
  BackButton,
  Button,
  cn,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  useConfirm,
  useCopyToClipboard,
  useScrolled,
} from '@spree/dashboard-ui'
import {
  BracesIcon,
  CheckIcon,
  CopyIcon,
  EllipsisVerticalIcon,
  TrashIcon,
} from '@spree/dashboard-ui/icons'
import type { JsonPreviewDrawerProps } from '@spree/dashboard-ui/spree/json-preview-drawer'
import { lazy, type ReactNode, Suspense, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useRegisterPageHeader } from '../providers/sticky-header-provider'
import { Slot } from './slot'

// JSON drawer is a developer-only feature; pulling its tree (which includes
// @uiw/react-json-view at ~30KB gzip) into the route bundle is wasteful.
// Lazy-load on first open so the chunk only ships to admins who use it.
// Deep subpath import bypasses the dashboard-ui barrel so the JSON view
// libs only live in the chunk Rollup splits off here.
const JsonPreviewDrawer = lazy(() =>
  import('@spree/dashboard-ui/spree/json-preview-drawer').then((m) => ({
    default: m.JsonPreviewDrawer,
  })),
)

/** Subset of `JsonPreviewDrawerProps` callers supply; PageHeader manages open state. */
export type PageHeaderJsonPreview = Pick<
  JsonPreviewDrawerProps,
  'title' | 'fetch' | 'endpoint' | 'resolveLink'
>

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
  /** Main title, on its own line. */
  title: ReactNode
  /** Small text beside the badges (updated_at badge, customer email, etc.). */
  subtitle?: ReactNode
  /** Back button target — passed to <BackButton fallback="..."/>. Omit for top-level pages. */
  backTo?: string
  /** Status badges, on the line under the title. Use <StatusBadge />. */
  badges?: ReactNode
  /** Primary action buttons (rightmost, before the dropdown). Most pages use this for "Save". */
  actions?: ReactNode
  /**
   * Domain-specific items for the top group of the more-actions dropdown
   * (e.g. Preview, Resend, Approve on orders). Rendered above the
   * `page.actions_dropdown` slot and the standard Copy ID / JSON items.
   *
   * Destructive entries belong in `destructiveItems`, not here — the dropdown
   * orders its three groups itself so every page reads the same way.
   */
  dropdownItems?: ReactNode
  /**
   * Destructive domain actions (Cancel order, a delete with its own confirm).
   * Always rendered last, in the same group as the auto-wired Delete, so a
   * page can never put a red item above the standard actions.
   */
  destructiveItems?: ReactNode
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
   * When provided, the Delete item is enabled. The prompt defaults to
   * "Are you sure? This action cannot be undone." — override the wording with
   * `deleteConfirmMessage`, or pass `dropdownItems` directly if you need a
   * different delete flow rather than different copy.
   */
  onDelete?: () => void | Promise<void>
  /** Override the destructive label ("Delete order", "Delete product", etc.). */
  deleteLabel?: string
  /**
   * Override the confirmation copy. Worth setting where deleting can be
   * refused, or where a neighbouring action does something different — the
   * generic "this cannot be undone" says neither.
   */
  deleteConfirmMessage?: string
  /**
   * When supplied, the more-actions dropdown gains a "View as JSON" item that
   * opens a developer-style drawer with the resource payload.
   */
  jsonPreview?: PageHeaderJsonPreview
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
  destructiveItems,
  resource,
  slotContext,
  onDelete,
  deleteLabel,
  deleteConfirmMessage,
  jsonPreview,
}: PageHeaderProps) {
  const { t } = useTranslation()
  const slotCtx = { ...slotContext, resource }
  const showDropdown = Boolean(
    resource || onDelete || dropdownItems || destructiveItems || jsonPreview,
  )
  const [jsonOpen, setJsonOpen] = useState(false)
  // Latches true on first open so the drawer (and its lazy JsonView chunk)
  // doesn't mount until the user actually invokes it, but stays mounted
  // afterwards so the close animation plays.
  const [jsonEverOpened, setJsonEverOpened] = useState(false)
  const openJson = () => {
    setJsonEverOpened(true)
    setJsonOpen(true)
  }
  const scrolled = useScrolled()
  // Tells the TopBar there's a header here to take over the top of the
  // viewport, so it may slide away once the user scrolls, and reports when
  // that hand-over is happening.
  const collapsed = useRegisterPageHeader()

  return (
    // This parks at `top-header-height`, directly below the TopBar, so the
    // title, badges, and primary actions (notably Save on form pages) stay
    // reachable as the user scrolls long detail pages.
    //
    // On scroll the TopBar retreats and this header rises to take its place.
    // That rise is a `translateY`, not a change of `top`: `top` is a layout
    // property with no transition, so animating it would teleport this header
    // 58px while the TopBar slid, visibly breaking the pair apart. Both now
    // move by the same distance, over the same duration and curve, off one
    // shared scroll flag.
    //
    // `bg-background` masks the content scrolling behind it;
    // `-mx-4 px-4 lg:-mx-6 lg:px-6` and `-mt-4 lg:-mt-6 pt-4 lg:pt-6` undo
    // and re-apply the parent padding so the sticky band runs edge-to-edge.
    //
    // The `::after` pseudo-element is the bottom hairline — it fades in
    // once the user scrolls (so the header blends at rest, separates when
    // content slides under it). A horizontal `mask-image` gradient feathers
    // the hairline's left/right edges to transparent so it doesn't visually
    // collide with the page edges; the `border-border` color it carries is
    // the same hairline used elsewhere in the app.
    <header
      className={cn(
        // One row at every width. The title truncates rather than wrapping,
        // so it yields space to the actions instead of pushing them onto a
        // second row — a page with only a Save button was spending two rows
        // of a short viewport on chrome.
        'sticky top-header-height z-20 -mx-4 -mt-4 flex flex-row items-start gap-2 bg-background/90 backdrop-blur supports-[backdrop-filter]:bg-background/75 px-4 pt-4 pb-3 sm:gap-3 lg:-mx-6 lg:-mt-6 lg:px-6 lg:pt-6',
        // `translate` is listed explicitly: Tailwind v4 compiles
        // `-translate-y-*` to the standalone `translate` property, so a
        // `transform`-only transition never animates it and the header would
        // jump to its raised position while the TopBar slid — the exact desync
        // this pairing exists to avoid.
        'transition-[transform,translate,box-shadow] duration-200 ease-out',
        // Reduced motion: hold position rather than teleport. Suppressing only
        // the transition would leave the 58px jump this pairing exists to avoid.
        'motion-reduce:transition-none motion-reduce:translate-y-0',
        'after:pointer-events-none after:absolute after:inset-x-0 after:bottom-0 after:h-px after:bg-border after:opacity-0 after:transition-opacity after:duration-200 after:[mask-image:linear-gradient(to_right,transparent,black_8%,black_92%,transparent)]',
        collapsed && '-translate-y-header-height',
        scrolled && 'after:opacity-100 shadow-xs',
      )}
    >
      {/* Row one: back button beside the title, so the arrow keeps its
          relationship to the heading rather than floating above it. */}
      <div className="flex min-w-0 flex-1 items-start gap-3">
        {backTo && <BackButton fallback={backTo} />}

        {/* The heading owns its line, with everything that qualifies it on
            the line below, so the eye reads the name first rather than
            picking it out of a row it shares. */}
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          {/* Smaller and clipped on a phone: sharing the row with the actions
              leaves a long product name too little width to wrap into
              anything readable. */}
          <h1 className="min-w-0 truncate font-medium text-xl leading-tight sm:text-2xl sm:whitespace-normal">
            {title}
          </h1>
          {/* Statuses and the timestamp share the second line: both answer
              "where is this now", so splitting them costs a row and reads as
              two separate facts. The subtitle is clamped on a phone, where a
              long one would make the sticky band tall enough to eat the page. */}
          {(badges || subtitle) && (
            <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
              {badges}
              {subtitle && (
                <span className="line-clamp-2 text-sm text-muted-foreground sm:line-clamp-none">
                  {subtitle}
                </span>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Pinned to the end of the row. `shrink-0` so the actions keep their
          full width and the title absorbs the shortfall. */}
      <div className="flex shrink-0 items-center justify-end gap-2 sm:ml-auto">
        <Slot name="page.actions" context={slotCtx} />
        {actions}
        {showDropdown && (
          <PageActionsDropdown
            resource={resource}
            slotContext={slotCtx}
            dropdownItems={dropdownItems}
            destructiveItems={destructiveItems}
            onDelete={onDelete}
            deleteLabel={deleteLabel ?? t('admin.actions.delete')}
            deleteConfirmMessage={deleteConfirmMessage}
            onOpenJson={jsonPreview ? openJson : undefined}
          />
        )}
      </div>

      {jsonPreview && jsonEverOpened && (
        <Suspense fallback={null}>
          <JsonPreviewDrawer open={jsonOpen} onOpenChange={setJsonOpen} {...jsonPreview} />
        </Suspense>
      )}
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
  destructiveItems?: ReactNode
  onDelete?: () => void | Promise<void>
  deleteLabel: string
  deleteConfirmMessage?: string
  onOpenJson?: () => void
}

function PageActionsDropdown({
  resource,
  slotContext,
  dropdownItems,
  destructiveItems,
  onDelete,
  deleteLabel,
  deleteConfirmMessage,
  onOpenJson,
}: PageActionsDropdownProps) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button size="icon" variant="outline" aria-label={t('admin.actions.more_actions')}>
          <EllipsisVerticalIcon className="size-4" />
        </Button>
      </DropdownMenuTrigger>
      {/* Three fixed groups, in this order: domain actions, standard actions,
          destructive actions. The order lives here rather than in each caller
          so every record page's menu reads the same way.

          Dividers are drawn by CSS (`:not(:empty) ~ :not(:empty)`) rather than
          by rendering a <DropdownMenuSeparator> between groups. A group's
          content can be present as a value but render nothing — an all-false
          fragment, or a plugin slot with no registrations — which a JS check
          reads as "has content" and would leave a divider floating against the
          menu's edge. `:empty` asks the DOM what actually rendered. */}
      <DropdownMenuContent
        align="end"
        className="[&>[data-menu-group]:not(:empty)~[data-menu-group]:not(:empty)]:mt-1 [&>[data-menu-group]:not(:empty)~[data-menu-group]:not(:empty)]:border-t [&>[data-menu-group]:not(:empty)~[data-menu-group]:not(:empty)]:border-border-subtle [&>[data-menu-group]:not(:empty)~[data-menu-group]:not(:empty)]:pt-1"
      >
        <div data-menu-group>
          {dropdownItems}
          <Slot name="page.actions_dropdown" context={slotContext} />
        </div>

        <div data-menu-group>
          {onOpenJson && (
            <DropdownMenuItem onClick={onOpenJson}>
              <BracesIcon className="size-4" />
              {t('admin.components.page_header.view_as_json')}
            </DropdownMenuItem>
          )}
          {resource?.number && (
            <CopyToClipboardItem
              label={t('admin.components.page_header.copy_number')}
              value={resource.number}
            />
          )}
          {resource && (
            <CopyToClipboardItem
              label={t('admin.components.page_header.copy_id')}
              value={resource.id}
            />
          )}
        </div>

        <div data-menu-group>
          {destructiveItems}
          {onDelete && (
            <DropdownMenuItem
              variant="destructive"
              onClick={async () => {
                if (
                  await confirm({
                    message: deleteConfirmMessage ?? t('admin.common.delete_confirm_message'),
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
          )}
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

// ---------------------------------------------------------------------------
// Copy-to-clipboard menu item
// ---------------------------------------------------------------------------

function CopyToClipboardItem({ label, value }: { label: string; value: string }) {
  const { t } = useTranslation()
  const { copied, copy } = useCopyToClipboard()

  return (
    <DropdownMenuItem
      // Keep the menu open after click so the user sees the confirmation flash.
      closeOnClick={false}
      onClick={(e) => {
        e.preventDefault()
        copy(value)
      }}
    >
      {copied ? <CheckIcon className="size-4" /> : <CopyIcon className="size-4" />}
      {copied ? t('admin.actions.copied') : label}
    </DropdownMenuItem>
  )
}
