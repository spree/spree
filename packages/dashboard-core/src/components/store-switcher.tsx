import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  SidebarMenu,
  SidebarMenuItem,
  Skeleton,
  useSidebar,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { CheckIcon, ChevronsUpDownIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useAuth } from '../hooks/use-auth'
import { useStore } from '../providers/store-provider'

/**
 * Sidebar store header. Renders a plain, non-interactive block when the
 * signed-in admin only has access to one store; becomes a dropdown listing
 * every store they hold a role on (from `user.stores`) once there are two
 * or more to switch between.
 */
export function StoreSwitcher() {
  const { t } = useTranslation()
  const { isMobile, state } = useSidebar()
  const isCollapsed = state === 'collapsed'

  const { store, isLoading } = useStore()
  const { user } = useAuth()

  if (isLoading) return <Skeleton className="h-header-height w-full rounded-xl" />

  const stores = user?.stores ?? []

  const storeInitials = store?.name
    .split(' ')
    .map((name) => name[0])
    .join('')

  const header = (
    <>
      <Avatar>
        {store?.logo_url && <AvatarImage src={store.logo_url} />}
        <AvatarFallback>{storeInitials}</AvatarFallback>
      </Avatar>
      {!isCollapsed && (
        <div className="grid flex-1 text-left text-sm leading-tight">
          <span className="truncate font-medium text-foreground">{store?.name}</span>
        </div>
      )}
    </>
  )

  if (stores.length < 2) {
    return (
      <SidebarMenu>
        <SidebarMenuItem className="h-header-height flex items-center">
          <div className="flex w-full items-center gap-2 p-1.5">{header}</div>
        </SidebarMenuItem>
      </SidebarMenu>
    )
  }

  return (
    <SidebarMenu>
      <SidebarMenuItem className="h-header-height flex items-center">
        <DropdownMenu>
          <DropdownMenuTrigger asChild className="flex w-full items-center">
            <button
              type="button"
              aria-label={t('admin.a11y.store_switcher')}
              className="rounded-xl outline-hidden transition-colors duration-100 hover:bg-sidebar-accent data-[state=open]:bg-sidebar-accent gap-2 p-1.5"
            >
              {header}
              {!isCollapsed && (
                <ChevronsUpDownIcon className="ml-auto size-4 text-muted-foreground" />
              )}
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="min-w-48"
            side={isMobile ? 'bottom' : 'right'}
            align="start"
            sideOffset={8}
          >
            {stores.map((availableStore) => (
              <DropdownMenuItem key={availableStore.id} asChild>
                {/* Built as a runtime path rather than a typed literal: core
                    is the framework behind more than one panel, and a panel
                    with no `/$storeId` route (a seller's) would fail to
                    typecheck against a route it never registers. Same approach
                    as the nav registries, which take paths as strings. */}
                <Link to={`/${availableStore.id}` as never} className="no-underline">
                  <span className="flex-1 truncate">{availableStore.name}</span>
                  {availableStore.id === store?.id && <CheckIcon className="size-4" />}
                </Link>
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
