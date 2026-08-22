import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Button,
  cn,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  LanguageMenuItems,
  SidebarTrigger,
  ThemeMenuItems,
  usePrefersReducedMotion,
} from '@spree/dashboard-ui'
import {
  BookOpenIcon,
  CommandIcon,
  ExternalLinkIcon,
  LogOutIcon,
  MailIcon,
  MessageCircleIcon,
  SearchIcon,
  UserIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useAuth } from '../hooks/use-auth'
import { useCommandPalette } from '../hooks/use-command-palette'
import { useSwitchAdminLocale } from '../hooks/use-switch-admin-locale'
import { getInitials } from '../lib/formatters'
import { i18n } from '../lib/i18n'
import { storefrontHref } from '../lib/storefront'
import { useStickyHeader } from '../providers/sticky-header-provider'
import { useStore } from '../providers/store-provider'

const IS_MAC = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform ?? '')

/**
 * Top-bar shell for the admin SPA. Three-slot layout:
 *   [☰ sidebar toggle]   [global search]   [view store · user menu]
 *
 * The search trigger opens the global ⌘K command palette (provider mounted at
 * the layout root). The keyboard shortcut is registered in the provider, not
 * here, so it works regardless of focus location.
 */
/**
 * @param uiLocales Admin UI languages for the in-menu switcher. The app owns
 *   which locale bundles ship (see the dashboard's `getAvailableUiLocales`) and
 *   injects them here, so this core component stays free of bundle knowledge.
 * @param onEditProfile Opens the app's edit-profile dialog. Injected the same
 *   way as `uiLocales` — the profile form lives in the app package (its hooks,
 *   schema and locale list do), so core only offers the menu entry. The item is
 *   hidden when no handler is supplied.
 */
export function TopBar({
  uiLocales = [],
  onEditProfile,
}: {
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
  onEditProfile?: () => void
}) {
  // Give the vertical space back to the page: once the user scrolls a detail
  // page, the PageHeader below carries the title and the primary actions, so
  // the search/account bar retreats out of the viewport rather than parking a
  // second band of chrome above it. The provider owns this flag so both bars
  // move off one signal; it stays false on pages with no PageHeader to take
  // over (list views), where hiding the bar would cost a header and give
  // nothing back.
  const { collapsed } = useStickyHeader()
  const prefersReducedMotion = usePrefersReducedMotion()
  // Under reduced motion the bar simply stays — sliding it is the movement
  // the setting asks us to drop, and cutting only the transition would
  // replace the slide with a jump, which is worse.
  const hidden = collapsed && !prefersReducedMotion

  return (
    <header
      className={cn(
        'sticky top-0 z-40 flex h-header-height shrink-0 items-center gap-3 bg-background/90 px-4 border-b border-border/75 backdrop-blur supports-[backdrop-filter]:bg-background/75',
        'transition-transform duration-200 ease-out motion-reduce:transition-none',
        hidden && '-translate-y-full',
      )}
      // Hidden from assistive tech and out of the tab order while off-screen,
      // so keyboard focus can't land on a control the user cannot see.
      inert={hidden || undefined}
    >
      {/* Size the glyph, not the button — `size="icon-sm"` sets a 28px hit area
          and overriding the box would shrink the target to 20px. */}
      <SidebarTrigger className="-ml-1 opacity-50 hover:bg-accent hover:opacity-100 [&_svg]:size-5" />

      <div className="flex flex-1 justify-center">
        <SearchTrigger />
      </div>

      <div className="flex items-center gap-2">
        <ViewStoreLink />
        <TopBarUser uiLocales={uiLocales} onEditProfile={onEditProfile} />
      </div>
    </header>
  )
}

// ---------------------------------------------------------------------------
// Search trigger — opens the global command palette
// ---------------------------------------------------------------------------

function SearchTrigger() {
  const { t } = useTranslation()
  const { setOpen } = useCommandPalette()

  return (
    <button
      type="button"
      onClick={() => setOpen(true)}
      // Focus matches the form inputs — the soft blue glow from `--ring`,
      // rather than a hard offset ring. It looks like a search field, so it
      // should focus like one.
      className="flex w-full max-w-md cursor-pointer items-center gap-1 rounded-xl border border-border px-2 py-1.5 text-sm text-muted-foreground outline-none transition-[color,background-color,border-color,box-shadow] duration-100 ease-out hover:bg-accent focus-visible:border-ring focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]"
    >
      <SearchIcon className="size-4" />
      <span className="flex-1 text-left">{t('admin.components.command_palette.placeholder')}</span>
      <kbd className="hidden rounded-lg border bg-background px-2 py-1 font-mono text-xs sm:inline-flex shadow-xs h-full">
        {IS_MAC ? <CommandIcon size={15} /> : 'Ctrl'}
      </kbd>
      <kbd className="hidden rounded-lg border bg-background px-2 py-1 font-mono text-xs sm:inline-flex shadow-xs">
        K
      </kbd>
    </button>
  )
}

// ---------------------------------------------------------------------------
// View Store link
// ---------------------------------------------------------------------------

function ViewStoreLink() {
  const { t } = useTranslation()
  const { store } = useStore()
  const href = storefrontHref(store)
  if (!href) return null

  return (
    <Button asChild variant="ghost" size="sm">
      <a href={href} target="_blank" rel="noreferrer">
        <ExternalLinkIcon className="size-4" />
        <span className="hidden sm:inline">{t('admin.account.view_store')}</span>
      </a>
    </Button>
  )
}

// ---------------------------------------------------------------------------
// User menu
// ---------------------------------------------------------------------------

/**
 * The account menu: who is signed in, theme and language, and sign out.
 *
 * Exported because it is the one piece of the top bar that needs nothing but
 * `useAuth` — no store, no command palette — so a panel with different chrome
 * (the seller panel) mounts this rather than forking a second user menu that
 * would then drift.
 */
export function TopBarUser({
  uiLocales = [],
  onEditProfile,
}: {
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
  onEditProfile?: () => void
}) {
  const { t } = useTranslation()
  const { user, logout } = useAuth()
  const switchAdminLocale = useSwitchAdminLocale()
  if (!user) return null

  const initials = getInitials(user.full_name, user.email)

  // Switching the admin UI language persists to the account, mirrors it into
  // the auth context, and reloads — see useSwitchAdminLocale for why all three
  // steps are required.
  const handleSelectLocale = (code: string) => {
    void switchAdminLocale(code)
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          aria-label={t('admin.a11y.user_menu')}
          className="flex items-center gap-2 rounded-lg p-1 transition-colors hover:bg-accent"
        >
          <Avatar className="size-7">
            {user.avatar_url && <AvatarImage src={user.avatar_url} alt="" />}
            <AvatarFallback className="bg-primary text-xs text-primary-foreground dark:bg-accent dark:text-foreground">
              {initials}
            </AvatarFallback>
          </Avatar>
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56" sideOffset={8}>
        <div className="flex items-center gap-2 p-1.5">
          <Avatar className="size-8">
            {user.avatar_url && <AvatarImage src={user.avatar_url} alt="" />}
            <AvatarFallback className="bg-primary text-xs text-primary-foreground dark:bg-accent dark:text-foreground">
              {initials}
            </AvatarFallback>
          </Avatar>
          <div className="grid min-w-0 flex-1 text-sm leading-tight">
            <span className="truncate font-medium text-foreground">
              {user.full_name || user.email}
            </span>
            {user.full_name && (
              <span className="truncate text-xs text-muted-foreground">{user.email}</span>
            )}
          </div>
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
          {t('admin.account.preferences')}
        </DropdownMenuLabel>
        <ThemeMenuItems />
        {/* Select-style pill; self-hides when < 2 languages are installed. */}
        <LanguageMenuItems
          label={t('admin.account.language.label')}
          locales={uiLocales}
          value={i18n.language}
          onSelect={handleSelectLocale}
        />
        <DropdownMenuSeparator />
        {onEditProfile && (
          <>
            <DropdownMenuItem onClick={onEditProfile}>
              <UserIcon className="size-4" />
              {t('admin.account.edit_profile')}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
          </>
        )}
        <DropdownMenuItem>
          <BookOpenIcon className="size-4" />
          {t('admin.account.documentation')}
        </DropdownMenuItem>
        <DropdownMenuItem>
          <MessageCircleIcon className="size-4" />
          {t('admin.account.community')}
        </DropdownMenuItem>
        <DropdownMenuItem>
          <MailIcon className="size-4" />
          {t('admin.account.contact_support')}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={logout} className="text-destructive focus:text-destructive">
          <LogOutIcon className="size-4" />
          {t('admin.account.log_out')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
