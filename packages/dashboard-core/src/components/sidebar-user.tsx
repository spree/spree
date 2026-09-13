import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  LanguageMenuItems,
  SidebarMenu,
  SidebarMenuItem,
  ThemeMenuItems,
  useSidebar,
} from '@spree/dashboard-ui'
import {
  BookOpenIcon,
  ExternalLinkIcon,
  LogOutIcon,
  MailIcon,
  MessageCircleIcon,
  MoreHorizontalIcon,
  UserIcon,
} from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useAuth } from '../hooks/use-auth'
import { useSwitchAdminLocale } from '../hooks/use-switch-admin-locale'
import { getInitials } from '../lib/formatters'
import { i18n } from '../lib/i18n'
import { storefrontHref } from '../lib/storefront'
import { useOptionalStore } from '../providers/store-provider'

/**
 * The account menu, sitting at the foot of the primary sidebar.
 *
 * It holds what the top bar's user menu held — who is signed in, theme,
 * language, the support links and sign out — because removing that bar left
 * the account with nowhere else to live, and the foot of the nav is where a
 * merchant already looks for it.
 *
 * `useOptionalStore` rather than `useStore`: the seller panel mounts this
 * under a `TenantProvider` with no store at all, and a hard `useStore` would
 * throw there. A panel without a store simply gets no "View store" entry.
 */
export function SidebarUser({
  uiLocales = [],
  onEditProfile,
  variant = 'sidebar',
}: {
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
  onEditProfile?: () => void
  /**
   * `bar` renders just the avatar as a compact button, for the mobile top
   * bar. The menu itself is identical — a phone should not get a smaller set
   * of account actions than a desktop, only a smaller way in to them.
   */
  variant?: 'sidebar' | 'bar'
}) {
  const { t } = useTranslation()
  const { isMobile, state } = useSidebar()
  const { user, logout } = useAuth()
  const switchAdminLocale = useSwitchAdminLocale()
  const store = useOptionalStore()?.store ?? null
  const viewStoreHref = storefrontHref(store)

  // The desktop rail's icon mode. The mobile drawer is full width whatever
  // that says, so honouring it there would hide the name for no reason.
  const isCollapsed = state === 'collapsed' && !isMobile

  if (!user) return null

  const initials = getInitials(user.full_name, user.email)

  // Persists to the account, mirrors it into the auth context, and reloads —
  // see useSwitchAdminLocale for why all three steps are required.
  const handleSelectLocale = (code: string) => {
    void switchAdminLocale(code)
  }

  const inBar = variant === 'bar'

  const trigger = (
    <DropdownMenuTrigger asChild>
      <button
        type="button"
        aria-label={t('admin.a11y.user_menu')}
        className={
          inBar
            ? 'inline-flex size-10 shrink-0 items-center justify-center rounded-lg outline-hidden transition-colors duration-100 hover:bg-accent data-[state=open]:bg-accent'
            : 'flex w-full items-center gap-2 rounded-xl p-1.5 outline-hidden transition-colors duration-100 hover:bg-sidebar-accent data-[state=open]:bg-sidebar-accent'
        }
      >
        <Avatar className="size-7 shrink-0 rounded-lg">
          {user.avatar_url && <AvatarImage src={user.avatar_url} alt="" />}
          <AvatarFallback className="rounded-lg bg-primary text-xs text-primary-foreground dark:bg-accent dark:text-foreground">
            {initials}
          </AvatarFallback>
        </Avatar>
        {!inBar && !isCollapsed && (
          <>
            <span className="min-w-0 flex-1 truncate text-left font-medium text-sm text-foreground">
              {user.full_name || user.email}
            </span>
            <MoreHorizontalIcon className="size-4 shrink-0 text-muted-foreground" />
          </>
        )}
      </button>
    </DropdownMenuTrigger>
  )

  const menu = (
    <DropdownMenu>
      {trigger}
      {/* In the rail the trigger sits at the bottom, so the menu opens
              upward or to the side or it would run off-screen. In the top bar
              it hangs below the avatar like any other header menu. */}
      <DropdownMenuContent
        className="w-56"
        side={inBar ? 'bottom' : isMobile ? 'top' : 'right'}
        align="end"
        sideOffset={8}
      >
        <div className="flex items-center gap-2 p-1.5">
          <Avatar className="size-8 rounded-lg">
            {user.avatar_url && <AvatarImage src={user.avatar_url} alt="" />}
            <AvatarFallback className="rounded-lg bg-primary text-xs text-primary-foreground dark:bg-accent dark:text-foreground">
              {initials}
            </AvatarFallback>
          </Avatar>
          <div className="grid min-w-0 flex-1 text-sm leading-tight">
            <span className="truncate font-medium text-foreground">
              {user.full_name || user.email}
            </span>
            {user.full_name && (
              <span className="truncate text-muted-foreground text-xs">{user.email}</span>
            )}
          </div>
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="font-medium text-muted-foreground text-xs uppercase tracking-wide">
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
        {/* The storefront link lost its home when the top bar went, and it
                belongs with the other outbound links rather than as a button
                competing with the nav. */}
        {viewStoreHref && (
          <DropdownMenuItem asChild>
            <a href={viewStoreHref} target="_blank" rel="noreferrer">
              <ExternalLinkIcon className="size-4" />
              {t('admin.account.view_store')}
            </a>
          </DropdownMenuItem>
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
        <DropdownMenuItem onClick={logout}>
          <LogOutIcon className="size-4" />
          {t('admin.account.log_out')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )

  // The bar places the button itself; only the rail needs the menu wrapped in
  // sidebar row markup.
  if (inBar) return menu

  return (
    <SidebarMenu>
      <SidebarMenuItem>{menu}</SidebarMenuItem>
    </SidebarMenu>
  )
}
