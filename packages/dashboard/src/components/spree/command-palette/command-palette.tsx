import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  StatusBadge,
} from '@spree/dashboard-ui'
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
import { useAuth } from '@/hooks/use-auth'
import { useCommandPalette } from '@/hooks/use-command-palette'
import { useGlobalSearch } from '@/hooks/use-global-search'
import { useTranslation } from '@/lib/i18n'

export function CommandPalette() {
  const { open, setOpen } = useCommandPalette()
  // Skip the entire subtree (and its hooks) while the palette is closed —
  // it's mounted at the layout root and otherwise re-renders on every nav.
  if (!open) return null

  return <CommandPaletteContent setOpen={setOpen} />
}

function CommandPaletteContent({ setOpen }: { setOpen: (open: boolean) => void }) {
  const { t } = useTranslation()
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
    { label: t('admin.nav.home'), icon: HomeIcon, to: '/$storeId' as const },
    { label: t('admin.nav.products'), icon: PackageIcon, to: '/$storeId/products' as const },
    { label: t('admin.nav.orders'), icon: ShoppingCartIcon, to: '/$storeId/orders' as const },
    { label: t('admin.nav.customers'), icon: UsersIcon, to: '/$storeId/customers' as const },
  ].filter((c) => matches(t('admin.components.command_palette.goto_label', { label: c.label })))
  const showLogout = matches(t('admin.auth.logout'))
  const hasResults = products.length > 0 || orders.length > 0 || customers.length > 0

  return (
    <Dialog
      open
      onOpenChange={(next) => {
        if (!next) close()
      }}
    >
      <DialogHeader className="sr-only">
        <DialogTitle>{t('admin.components.command_palette.title')}</DialogTitle>
        <DialogDescription>{t('admin.components.command_palette.description')}</DialogDescription>
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
            placeholder={t('admin.components.command_palette.placeholder')}
          />
          <CommandList>
            <SearchStatus
              isEnabled={isEnabled}
              isLoading={isLoading}
              hasResults={hasResults}
              query={input}
            />

            {products.length > 0 && (
              <CommandGroup heading={t('admin.nav.products')}>
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
              <CommandGroup heading={t('admin.nav.orders')}>
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
              <CommandGroup heading={t('admin.nav.customers')}>
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
              <CommandGroup heading={t('admin.components.command_palette.goto')}>
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
              <CommandGroup heading={t('admin.nav.account')}>
                <CommandItem
                  value="action-logout"
                  onSelect={() => {
                    close()
                    logout()
                  }}
                >
                  <LogOutIcon />
                  {t('admin.auth.logout')}
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
  const { t } = useTranslation()
  if (isEnabled && isLoading) {
    return (
      <div className="flex items-center justify-center gap-2 py-6 text-sm text-muted-foreground">
        <Loader2Icon className="size-4 animate-spin" />
        {t('admin.common.searching')}
      </div>
    )
  }
  if (isEnabled && !hasResults) {
    return (
      <CommandEmpty>{t('admin.components.command_palette.no_results', { query })}</CommandEmpty>
    )
  }
  if (!isEnabled && !query) {
    return <CommandEmpty>{t('admin.components.command_palette.empty_hint')}</CommandEmpty>
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
