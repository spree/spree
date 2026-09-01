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
import { CheckIcon, ChevronsUpDownIcon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { Link, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * Sidebar seller header, mirroring the operator's store switcher.
 *
 * A plain, non-interactive block when the signed-in person runs one seller —
 * which is most of them — and a dropdown listing every seller they hold a
 * role on once there are two or more. Switching is a link to the other
 * seller's route, so the URL stays the source of truth for who is being
 * acted as, exactly as the store switcher navigates by store id.
 *
 * Replaces the fixed "Seller panel" label, which told a seller something
 * they already knew and left their own name off the one piece of chrome
 * that is always on screen.
 */
export function SellerSwitcher() {
  const { t } = useTranslation()
  const { isMobile, state } = useSidebar()
  const isCollapsed = state === 'collapsed'
  const { sellerId } = useParams({ strict: false }) as { sellerId?: string }

  // `/me` for the list, the profile for the current seller's own logo — the
  // summary in `/me` carries no image, and the profile query is already
  // loaded by the page behind this.
  const { data: me, isLoading } = useQuery({
    queryKey: ['seller', 'me'],
    queryFn: () => sellerClient().me(),
  })

  const { data: profile } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
    enabled: Boolean(sellerId),
  })

  if (isLoading) return <Skeleton className="h-header-height w-full rounded-xl" />

  const sellers = me?.sellers ?? []
  const current = sellers.find((seller) => seller.id === sellerId) ?? sellers[0]

  const initials = current?.name
    .split(' ')
    .map((word) => word[0])
    .join('')

  const header = (
    <>
      <Avatar>
        {profile?.square_logo_url || profile?.logo_url ? (
          <AvatarImage src={profile.square_logo_url ?? profile.logo_url ?? undefined} />
        ) : null}
        <AvatarFallback>{initials}</AvatarFallback>
      </Avatar>
      {!isCollapsed && (
        <div className="grid flex-1 text-left text-sm leading-tight">
          <span className="truncate font-medium text-foreground">{current?.name}</span>
        </div>
      )}
    </>
  )

  if (sellers.length < 2) {
    return (
      <SidebarMenu>
        <SidebarMenuItem className="flex h-header-height items-center">
          <div className="flex w-full items-center gap-2 p-1.5">{header}</div>
        </SidebarMenuItem>
      </SidebarMenu>
    )
  }

  return (
    <SidebarMenu>
      <SidebarMenuItem className="flex h-header-height items-center">
        <DropdownMenu>
          <DropdownMenuTrigger asChild className="flex w-full items-center">
            <button
              type="button"
              aria-label={t('seller_switcher.label')}
              className="gap-2 rounded-xl p-1.5 outline-hidden transition-colors duration-100 hover:bg-sidebar-accent data-[state=open]:bg-sidebar-accent"
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
            {sellers.map((seller) => (
              <DropdownMenuItem key={seller.id} asChild>
                <Link to="/$sellerId" params={{ sellerId: seller.id }} className="no-underline">
                  <span className="flex-1 truncate">{seller.name}</span>
                  {seller.id === current?.id && <CheckIcon className="size-4" />}
                </Link>
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
