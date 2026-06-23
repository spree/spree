import {
  Avatar,
  AvatarFallback,
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  LanguageMenuItems,
  SidebarTrigger,
  ThemeMenuItems,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import {
  BookOpenIcon,
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
 */
export function TopBar({
  uiLocales = [],
}: {
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
}) {
  return (
    <header className="sticky top-0 z-40 flex h-header-height shrink-0 items-center gap-3 bg-background/90 px-4 border-b border-border/50 backdrop-blur supports-[backdrop-filter]:bg-background/75">
      <SidebarTrigger className="-ml-1 h-8 w-8" />

      <div className="flex flex-1 justify-center">
        <SearchTrigger />
      </div>

      <div className="flex items-center gap-2">
        <ViewStoreLink />
        <TopBarUser uiLocales={uiLocales} />
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
      className="flex w-full max-w-md items-center gap-2 rounded-lg border border-border bg-muted/40 px-2 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-muted"
    >
      <SearchIcon className="size-4" />
      <span className="flex-1 text-left">{t('admin.components.command_palette.placeholder')}</span>
      <kbd className="hidden rounded border bg-background px-1.5 py-0.5 font-mono text-xs sm:inline-flex">
        {IS_MAC ? '⌘K' : 'Ctrl+K'}
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
  if (!store?.url) return null

  // Best-effort: prefix with https if the URL is just a hostname.
  const href = /^https?:\/\//.test(store.url) ? store.url : `https://${store.url}`

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

function TopBarUser({ uiLocales }: { uiLocales: ReadonlyArray<{ code: string; name: string }> }) {
  const { t } = useTranslation()
  const { user, logout } = useAuth()
  const { store } = useStore()
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
            <AvatarFallback className="bg-primary text-xs text-primary-foreground dark:bg-accent dark:text-foreground">
              {initials}
            </AvatarFallback>
          </Avatar>
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56" sideOffset={8}>
        <div className="flex items-center gap-2 p-1.5">
          <Avatar className="size-8">
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
        <ThemeMenuItems />
        {/* Compact nested submenu; self-hides when < 2 languages are installed. */}
        <LanguageMenuItems
          label={t('admin.account.language.label')}
          locales={uiLocales}
          value={i18n.language}
          onSelect={handleSelectLocale}
        />
        {uiLocales.length >= 2 && <DropdownMenuSeparator />}
        {store && (
          <DropdownMenuItem asChild>
            <Link
              to="/$storeId/settings/profile"
              params={{ storeId: store.id }}
              className="no-underline"
            >
              <UserIcon className="size-4" />
              {t('admin.account.edit_profile')}
            </Link>
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
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
