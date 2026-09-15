import { SidebarTrigger, Skeleton } from '@spree/dashboard-ui'
import { SearchIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useOptionalCommandPalette } from '../hooks/use-command-palette'
import { useOptionalStore } from '../providers/store-provider'
import { SidebarUser } from './sidebar-user'

/**
 * The bar a phone gets in place of the nav rail.
 *
 * On a narrow screen the rail is an off-canvas drawer, so something on the
 * page has to open it — and after the shell moved the account menu and the
 * search box into the rail, that trigger is the only way to reach either of
 * them. Without this bar the drawer has no opener at all and the nav is
 * simply unreachable, which is why it renders unconditionally rather than
 * only where a breadcrumb trail exists.
 *
 * Deliberately thin: the trigger, the store it belongs to, and search. Page
 * titles and actions stay with `PageHeader` below, so this never becomes a
 * second place to look for them.
 */
export function MobileTopBar({
  uiLocales = [],
  onEditProfile,
  title,
}: {
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
  onEditProfile?: () => void
  /** Name shown beside the controls. Defaults to the store's, for panels that have one. */
  title?: string
} = {}) {
  const { t } = useTranslation()
  // `useOptionalStore` rather than `useStore`: the seller panel mounts this
  // under a `TenantProvider` with no store at all, and a hard `useStore`
  // throws there — taking every seller page down at phone width. A panel
  // without a store passes its own `title` instead.
  const storeContext = useOptionalStore()
  // Absent in panels that mount no palette (the seller panel), where the
  // search button would open nothing.
  const palette = useOptionalCommandPalette()

  const label = title ?? storeContext?.store?.name
  // Only a store-backed panel has a name still loading; one that passes its
  // own title has nothing to wait for.
  const isLoading = title === undefined && (storeContext?.isLoading ?? false)

  return (
    // `h-14` (56px) is the phone top-bar height on Android, and comfortably
    // clears the 44pt iOS navigation bar; the controls inside are `size-11`
    // (44px), the touch target both platforms ask for and the size this
    // codebase already uses for mobile controls in the table toolbar.
    <div className="sticky top-0 z-30 flex h-14 shrink-0 items-center gap-1 border-b border-border bg-card px-2 md:hidden">
      <SidebarTrigger className="size-11 shrink-0 text-muted-foreground hover:bg-accent hover:text-foreground" />

      {isLoading ? (
        <Skeleton className="h-4 w-28" />
      ) : (
        <span className="min-w-0 flex-1 truncate font-medium text-sm">{label}</span>
      )}

      {palette && (
        <button
          type="button"
          onClick={() => palette.setOpen(true)}
          aria-label={t('admin.components.command_palette.search_label')}
          className="inline-flex size-11 shrink-0 items-center justify-center rounded-lg text-muted-foreground transition-colors duration-100 hover:bg-accent hover:text-foreground"
        >
          <SearchIcon className="size-5" />
        </button>
      )}

      <SidebarUser variant="bar" uiLocales={uiLocales} onEditProfile={onEditProfile} />
    </div>
  )
}
