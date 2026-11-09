import {
  SidebarMenu,
  SidebarMenuItem,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  useSidebar,
} from '@spree/dashboard-ui'
import { SearchIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useOptionalCommandPalette } from '../hooks/use-command-palette'

const IS_MAC = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform ?? '')

/**
 * Opens the global ⌘K palette, sitting under the store switcher.
 *
 * The shortcut itself is registered by the palette's provider, not here, so it
 * works wherever focus is — this is only the visible affordance for it.
 *
 * Collapsed to the icon rail it becomes a plain square button: a search field
 * with no room for text reads as a broken input, whereas an icon reads as a
 * button that will open something.
 *
 * Renders nothing when no palette is mounted — the seller panel has none yet,
 * and a search box that opens nothing is worse than no search box.
 */
export function SidebarSearch() {
  const { t } = useTranslation()
  const palette = useOptionalCommandPalette()
  const { isMobile, state } = useSidebar()
  const isCollapsed = state === 'collapsed' && !isMobile
  // Just "Search": the bar is an affordance, not a field, so it names the
  // action and leaves the palette's own placeholder to say what is searchable.
  const label = t('admin.actions.search')

  if (!palette) return null

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <Tooltip>
          <TooltipTrigger asChild>
            <button
              type="button"
              onClick={() => palette.setOpen(true)}
              aria-label={isCollapsed ? label : undefined}
              // A field's fill and edge, without its shadow: it reads as the
              // search box it opens, and stays flat on the rail. Focus is the
              // inputs' soft blue glow from `--ring`.
              className={
                isCollapsed
                  ? // `size-10` matches what a nav item collapses to, so the rail reads
                    // as one column of equal targets rather than a search box that
                    // shrank. The glyph stays 16px, as `NavIcon` draws it.
                    'flex size-10 items-center justify-center rounded-lg text-muted-foreground outline-none transition-colors duration-100 ease-out hover:bg-sidebar-accent-hover hover:text-foreground focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]'
                  : 'flex w-full cursor-pointer items-center gap-2 rounded-xl border border-field-border bg-card py-1.5 ps-2.5 pe-2.5 text-muted-foreground text-sm outline-none transition-[color,border-color,box-shadow] duration-100 ease-out hover:text-foreground focus-visible:border-ring focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]'
              }
            >
              <SearchIcon className="size-4 shrink-0" />
              {!isCollapsed && (
                <>
                  <span className="flex-1 truncate text-left">{label}</span>
                  {/* The shortcut as quiet text, not a keycap: a hint, not a control. */}
                  <kbd className="hidden font-sans text-xs tabular-nums text-muted-foreground sm:inline">
                    {IS_MAC ? '⌘K' : 'Ctrl K'}
                  </kbd>
                </>
              )}
            </button>
          </TooltipTrigger>
          {/* Only while collapsed: expanded, the label is already on screen and
              a tooltip would repeat it. Matches how `SidebarMenuButton` gates
              the nav items' own tooltips. */}
          <TooltipContent side="right" align="center" hidden={!isCollapsed}>
            {label}
          </TooltipContent>
        </Tooltip>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
