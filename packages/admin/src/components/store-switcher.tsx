import { ChevronsUpDownIcon, ExternalLinkIcon, PaletteIcon, StoreIcon } from 'lucide-react'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { SidebarMenu, SidebarMenuItem, useSidebar } from '@/components/ui/sidebar'

export function StoreSwitcher() {
  const { isMobile, state } = useSidebar()
  const isCollapsed = state === 'collapsed'

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              className={
                'flex w-full items-center rounded-xl outline-hidden transition-colors duration-100 hover:bg-gray-200/50 data-[state=open]:bg-gray-200/50 ' +
                (isCollapsed ? 'size-10 justify-center p-0' : 'h-[58px] gap-2 p-1')
              }
            >
              <div className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-zinc-950 text-white">
                <StoreIcon className="size-4" />
              </div>
              {!isCollapsed && (
                <>
                  <div className="grid flex-1 text-left text-sm leading-tight">
                    <span className="truncate font-medium text-zinc-950">Spree Store</span>
                  </div>
                  <ChevronsUpDownIcon className="ml-auto size-4 text-gray-400" />
                </>
              )}
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="min-w-48"
            side={isMobile ? 'bottom' : 'right'}
            align="start"
            sideOffset={8}
          >
            <DropdownMenuItem>
              <ExternalLinkIcon className="size-4" />
              View Store
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem>
              <PaletteIcon className="size-4" />
              Edit Theme
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
