import { TablerIcon } from '@/components/tabler-icon'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { SidebarMenu, SidebarMenuItem, useSidebar } from '@/components/ui/sidebar'
import { useAuth } from '@/hooks/use-auth'

export function NavUser() {
  const { isMobile } = useSidebar()
  const { user, logout } = useAuth()

  if (!user) return null

  const initials =
    [user.first_name, user.last_name]
      .filter(Boolean)
      .map((n) => n![0])
      .join('')
      .toUpperCase() || user.email[0]!.toUpperCase()

  const displayName = [user.first_name, user.last_name].filter(Boolean).join(' ') || user.email

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              className="flex w-full items-center gap-2 rounded-lg p-1 text-left hover:bg-gray-200/50 transition-colors duration-100 outline-none"
            >
              <Avatar className="size-8">
                <AvatarFallback className="text-xs bg-zinc-950 text-white">
                  {initials}
                </AvatarFallback>
              </Avatar>
              <span className="flex-1 min-w-0 truncate text-sm text-zinc-950">{displayName}</span>
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="w-56"
            side={isMobile ? 'top' : 'right'}
            align="end"
            sideOffset={8}
          >
            {/* Profile card */}
            <div className="px-2.5 py-2.5">
              <div className="flex items-center gap-3 rounded-xl bg-muted p-2.5">
                <Avatar className="size-8">
                  <AvatarFallback className="text-xs bg-zinc-950 text-white">
                    {initials}
                  </AvatarFallback>
                </Avatar>
                <div className="grid flex-1 min-w-0 text-sm leading-tight">
                  <span className="truncate font-medium text-zinc-950">{displayName}</span>
                  <span className="truncate text-xs text-muted-foreground">{user.email}</span>
                </div>
              </div>
            </div>
            <DropdownMenuSeparator />
            <DropdownMenuItem>
              <TablerIcon name="user-scan" />
              Edit Profile
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem>
              <TablerIcon name="book" />
              Documentation
            </DropdownMenuItem>
            <DropdownMenuItem>
              <TablerIcon name="message-circle" />
              Community
            </DropdownMenuItem>
            <DropdownMenuItem>
              <TablerIcon name="mail" />
              Contact Support
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={logout} className="text-destructive focus:text-destructive">
              <TablerIcon name="log-out" />
              Log out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
