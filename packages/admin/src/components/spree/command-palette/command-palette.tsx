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
import { type ReactNode, useDeferredValue, useState } from 'react'
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
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const navigate = useNavigate()
  const { logout } = useAuth()

  const [input, setInput] = useState('')
  // Defer keystrokes so React batches; also lets us debounce server queries
  // implicitly via React's scheduling.
  const deferredInput = useDeferredValue(input)
  const { products, orders, customers, isLoading, isEnabled } = useGlobalSearch(deferredInput)

  function go(to: string) {
    setOpen(false)
    setInput('')
    navigate({ to })
  }

  // Static commands always render their full label & we filter in-memory by
  // substring. cmdk's built-in filter is off (we drive resource results from
  // the server), so we hand-filter the static groups here.
  const q = deferredInput.trim().toLowerCase()
  const matches = (label: string) => !q || label.toLowerCase().includes(q)
  const gotoItems = [
    { label: 'Dashboard', icon: HomeIcon, to: `/${storeId ?? 'default'}` },
    { label: 'Products', icon: PackageIcon, to: `/${storeId ?? 'default'}/products` },
    { label: 'Orders', icon: ShoppingCartIcon, to: `/${storeId ?? 'default'}/orders` },
    { label: 'Customers', icon: UsersIcon, to: `/${storeId ?? 'default'}/customers` },
  ].filter((c) => matches(`Go to ${c.label}`))
  const showLogout = matches('Log out')

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) setInput('')
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
        // The palette closes by navigating elsewhere; don't bounce focus back
        // to the prior trigger (which lands on the first sidebar item and
        // shows a misleading focus ring). Browser falls back to body.
        finalFocus={false}
      >
        {/* Server's `search` Ransack scope already filters resources; static
            commands are pre-filtered in JS, so cmdk's client-side filter is
            unnecessary and would re-filter our already-curated lists. */}
        <Command shouldFilter={false}>
          <CommandInput
            value={input}
            onValueChange={setInput}
            placeholder="Search products, orders, customers… or run a command"
          />
          <CommandList>
            {isEnabled && isLoading ? (
              <div className="flex items-center justify-center gap-2 py-6 text-sm text-muted-foreground">
                <Loader2Icon className="size-4 animate-spin" />
                Searching…
              </div>
            ) : (
              isEnabled &&
              products.length === 0 &&
              orders.length === 0 &&
              customers.length === 0 && (
                <CommandEmpty>No results for "{deferredInput}".</CommandEmpty>
              )
            )}

            {!isEnabled && !input && (
              <CommandEmpty>Type to search, or pick a command below.</CommandEmpty>
            )}

            {products.length > 0 && (
              <CommandGroup heading="Products">
                {products.map((p) => (
                  <CommandItem
                    key={p.id}
                    value={`product-${p.id}`}
                    onSelect={() => go(`/${storeId ?? 'default'}/products/${p.id}`)}
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
                    onSelect={() => go(`/${storeId ?? 'default'}/orders/${o.id}`)}
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
                    onSelect={() => go(`/${storeId ?? 'default'}/customers/${c.id}`)}
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

            {(products.length > 0 || orders.length > 0 || customers.length > 0) &&
              (gotoItems.length > 0 || showLogout) && <CommandSeparator />}

            {gotoItems.length > 0 && (
              <CommandGroup heading="Go to">
                {gotoItems.map(({ label, icon: Icon, to }) => (
                  <CommandItem key={to} value={`goto-${label}`} onSelect={() => go(to)}>
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
                    setOpen(false)
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

function ProductIconOrThumbnail({ thumbnailUrl }: { thumbnailUrl: string | null }): ReactNode {
  if (thumbnailUrl) {
    return (
      <img
        src={thumbnailUrl}
        alt=""
        className="size-5 shrink-0 rounded object-cover"
        loading="lazy"
      />
    )
  }
  return <TagIcon />
}
