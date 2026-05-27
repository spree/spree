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
import { ThemeMenuItems } from '@/components/spree/theme-toggle'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { SidebarTrigger } from '@/components/ui/sidebar'
import { useAuth } from '@/hooks/use-auth'
import { useCommandPalette } from '@/hooks/use-command-palette'
import { getInitials } from '@/lib/formatters'
import { useStore } from '@/providers/store-provider'

const IS_MAC = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform ?? '')

/**
 * Top-bar shell for the admin SPA. Three-slot layout:
 *   [☰ sidebar toggle]   [global search]   [view store · user menu]
 *
 * The search trigger opens the global ⌘K command palette (provider mounted at
 * the layout root). The keyboard shortcut is registered in the provider, not
 * here, so it works regardless of focus location.
 */
export function TopBar() {
  return (
    <header className="sticky top-0 z-40 flex h-header-height shrink-0 items-center gap-3 bg-background/90 px-4 border-b border-border/50 backdrop-blur supports-[backdrop-filter]:bg-background/75">
      <SidebarTrigger className="-ml-1 h-8 w-8" />

      <div className="flex flex-1 justify-center">
        <SearchTrigger />
      </div>

      <div className="flex items-center gap-2">
        <ViewStoreLink />
        <TopBarUser />
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
  const { store } = useStore()
  if (!store?.url) return null

  // Best-effort: prefix with https if the URL is just a hostname.
  const href = /^https?:\/\//.test(store.url) ? store.url : `https://${store.url}`

  return (
    <Button asChild variant="ghost" size="sm">
      <a href={href} target="_blank" rel="noreferrer">
        <ExternalLinkIcon className="size-4" />
        <span className="hidden sm:inline">View store</span>
      </a>
    </Button>
  )
}

// ---------------------------------------------------------------------------
// User menu
// ---------------------------------------------------------------------------

function TopBarUser() {
  const { t } = useTranslation()
  const { user, logout } = useAuth()
  if (!user) return null

  const initials = getInitials(user.full_name, user.email)

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
        <DropdownMenuItem>
          <UserIcon className="size-4" />
          Edit Profile
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem>
          <BookOpenIcon className="size-4" />
          Documentation
        </DropdownMenuItem>
        <DropdownMenuItem>
          <MessageCircleIcon className="size-4" />
          Community
        </DropdownMenuItem>
        <DropdownMenuItem>
          <MailIcon className="size-4" />
          Contact Support
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={logout} className="text-destructive focus:text-destructive">
          <LogOutIcon className="size-4" />
          Log out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
