import { useNavigate, useParams } from '@tanstack/react-router'
import {
  HomeIcon,
  Loader2Icon,
  LogOutIcon,
  PackageIcon,
  ShoppingCartIcon,
  TagIcon,
  UsersIcon,
} from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { StatusBadge } from '@/components/ui/badge'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from '@/components/ui/command'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useAuth } from '@/hooks/use-auth'
import { useCommandPalette } from '@/hooks/use-command-palette'
import { useGlobalSearch } from '@/hooks/use-global-search'

export function CommandPalette() {
  const { open, setOpen } = useCommandPalette()
  // Skip the entire subtree (and its hooks) while the palette is closed —
  // it's mounted at the layout root and otherwise re-renders on every nav.
  if (!open) return null

  return <CommandPaletteContent setOpen={setOpen} />
}

function CommandPaletteContent({ setOpen }: { setOpen: (open: boolean) => void }) {
  const { storeId: rawStoreId } = useParams({ strict: false }) as { storeId?: string }
  const storeId = rawStoreId ?? 'default'
  const navigate = useNavigate()
  const { logout } = useAuth()

  const [input, setInput] = useState('')
  const { products, orders, customers, isLoading, isEnabled } = useGlobalSearch(input)

  const close = () => {
    setOpen(false)
    setInput('')
  }

  const q = input.trim().toLowerCase()
  const matches = (label: string) => !q || label.toLowerCase().includes(q)
  const gotoItems = [
    { label: 'Dashboard', icon: HomeIcon, to: '/$storeId' as const },
    { label: 'Products', icon: PackageIcon, to: '/$storeId/products' as const },
    { label: 'Orders', icon: ShoppingCartIcon, to: '/$storeId/orders' as const },
    { label: 'Customers', icon: UsersIcon, to: '/$storeId/customers' as const },
  ].filter((c) => matches(`Go to ${c.label}`))
  const showLogout = matches('Log out')
  const hasResults = products.length > 0 || orders.length > 0 || customers.length > 0

  return (
    <Dialog
      open
      onOpenChange={(next) => {
        if (!next) close()
      }}
    >
      <DialogHeader className="sr-only">
        <DialogTitle>Search and commands</DialogTitle>
        <DialogDescription>
          Search across products, orders, and customers, or run a command.
        </DialogDescription>
      </DialogHeader>
      <DialogContent
        className="top-1/3 translate-y-0 overflow-hidden p-0 sm:max-w-2xl"
        showCloseButton={false}
        // Don't restore focus to the trigger after navigating — the trigger is
        // gone (we navigated away) and focus would land on the first sidebar
        // link, painting it with a misleading focus ring.
        finalFocus={false}
      >
        {/* Server's `search` Ransack scope filters resources; static commands
            are pre-filtered in JS. Either way, cmdk shouldn't filter again. */}
        <Command shouldFilter={false}>
          <CommandInput
            value={input}
            onValueChange={setInput}
            placeholder="Search products, orders, customers… or run a command"
          />
          <CommandList>
            <SearchStatus
              isEnabled={isEnabled}
              isLoading={isLoading}
              hasResults={hasResults}
              query={input}
            />

            {products.length > 0 && (
              <CommandGroup heading="Products">
                {products.map((p) => (
                  <CommandItem
                    key={p.id}
                    value={`product-${p.id}`}
                    onSelect={() => {
                      close()
                      navigate({
                        to: '/$storeId/products/$productId',
                        params: { storeId, productId: p.id },
                      })
                    }}
                  >
                    <ProductIconOrThumbnail thumbnailUrl={p.primary_media?.mini_url ?? null} />
                    <span className="flex-1 truncate">{p.name}</span>
                    <StatusBadge status={p.status} />
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {orders.length > 0 && (
              <CommandGroup heading="Orders">
                {orders.map((o) => (
                  <CommandItem
                    key={o.id}
                    value={`order-${o.id}`}
                    onSelect={() => {
                      close()
                      navigate({
                        to: '/$storeId/orders/$orderId',
                        params: { storeId, orderId: o.id },
                      })
                    }}
                  >
                    <ShoppingCartIcon />
                    <span className="flex-1 truncate">
                      <span className="font-mono">{o.number}</span>
                      {o.email && <span className="ml-2 text-muted-foreground">{o.email}</span>}
                    </span>
                    {o.payment_status && <StatusBadge status={o.payment_status} />}
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {customers.length > 0 && (
              <CommandGroup heading="Customers">
                {customers.map((c) => (
                  <CommandItem
                    key={c.id}
                    value={`customer-${c.id}`}
                    onSelect={() => {
                      close()
                      navigate({
                        to: '/$storeId/customers/$customerId',
                        params: { storeId, customerId: c.id },
                      })
                    }}
                  >
                    <UsersIcon />
                    <span className="flex-1 truncate">
                      {c.full_name || c.email}
                      {c.full_name && <span className="ml-2 text-muted-foreground">{c.email}</span>}
                    </span>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {hasResults && (gotoItems.length > 0 || showLogout) && <CommandSeparator />}

            {gotoItems.length > 0 && (
              <CommandGroup heading="Go to">
                {gotoItems.map(({ label, icon: Icon, to }) => (
                  <CommandItem
                    key={to}
                    value={`goto-${label}`}
                    onSelect={() => {
                      close()
                      navigate({ to, params: { storeId } })
                    }}
                  >
                    <Icon />
                    {label}
                  </CommandItem>
                ))}
              </CommandGroup>
            )}

            {gotoItems.length > 0 && showLogout && <CommandSeparator />}

            {showLogout && (
              <CommandGroup heading="Account">
                <CommandItem
                  value="action-logout"
                  onSelect={() => {
                    close()
                    logout()
                  }}
                >
                  <LogOutIcon />
                  Log out
                </CommandItem>
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function SearchStatus({
  isEnabled,
  isLoading,
  hasResults,
  query,
}: {
  isEnabled: boolean
  isLoading: boolean
  hasResults: boolean
  query: string
}): ReactNode {
  if (isEnabled && isLoading) {
    return (
      <div className="flex items-center justify-center gap-2 py-6 text-sm text-muted-foreground">
        <Loader2Icon className="size-4 animate-spin" />
        Searching…
      </div>
    )
  }
  if (isEnabled && !hasResults) {
    return <CommandEmpty>No results for "{query}".</CommandEmpty>
  }
  if (!isEnabled && !query) {
    return <CommandEmpty>Type to search, or pick a command below.</CommandEmpty>
  }
  return null
}

function ProductIconOrThumbnail({ thumbnailUrl }: { thumbnailUrl: string | null }): ReactNode {
  if (!thumbnailUrl) return <TagIcon />
  return (
    <img
      src={thumbnailUrl}
      alt=""
      className="size-5 shrink-0 rounded object-cover"
      loading="lazy"
    />
  )
}
