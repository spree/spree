import { ChevronsUpDownIcon, ExternalLinkIcon } from 'lucide-react'
import { TablerIcon } from '@/components/tabler-icon'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from '@/components/ui/sidebar'

export function StoreSwitcher() {
  const { isMobile } = useSidebar()

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <SidebarMenuButton
              size="lg"
              className="h-[58px] gap-2 rounded-xl p-1 hover:bg-gray-200/50 data-[state=open]:bg-gray-200/50"
            >
              <div className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-zinc-950 text-white">
                <TablerIcon name="building-store" className="size-4" />
              </div>
              <div className="grid flex-1 text-left text-sm leading-tight">
                <span className="truncate font-medium text-zinc-950">Spree Store</span>
              </div>
              <ChevronsUpDownIcon className="ml-auto size-4 text-gray-400" />
            </SidebarMenuButton>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="w-(--radix-dropdown-menu-trigger-width) min-w-48"
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
              <TablerIcon name="palette" className="size-4" />
              Edit Theme
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
