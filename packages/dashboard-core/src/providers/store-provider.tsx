import type { Store } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { createContext, type ReactNode, useCallback, useContext, useEffect, useRef } from 'react'
import { adminClient } from '../client'
import { useAuth } from '../hooks/use-auth'
import { coreLocaleCodes, reconcileStoreDefaultLocale } from '../lib/i18n'

/**
 * Resource segment of the store query key: the current store lives in the
 * TanStack cache under `['store', storeId]` (the canonical
 * `[resource, storeId]` shape). Mutations that change anything the store
 * payload derives from — setup-task completion, supported locales/currencies —
 * add `[[STORE_QUERY_RESOURCE]]` to their `useResourceMutation` invalidate
 * list so every consumer (nav badge, Getting Started, pickers) refreshes.
 */
export const STORE_QUERY_RESOURCE = 'store'

interface StoreContextValue {
  store: Store | null
  storeId: string
  isLoading: boolean
  currencies: string[]
  /** Locales this store is configured to translate content into. */
  locales: string[]
  /** Every locale a merchant may translate content into — the full canonical
   *  set, independent of which locales the store currently uses. Drives locale
   *  pickers so a new locale can always be added. */
  availableLocales: string[]
  defaultCurrency: string
  defaultLocale: string
  /** IANA timezone for the store (e.g. `Europe/Berlin`). Falls back to the
   *  browser's resolved timezone when the store hasn't loaded yet. */
  timezone: string
  refetch: () => Promise<void>
}

const StoreContext = createContext<StoreContextValue | null>(null)

export function StoreProvider({ storeId, children }: { storeId: string; children: ReactNode }) {
  const { user } = useAuth()

  // Read the account locale through a ref so a `user` identity change (frequent —
  // every auth update) doesn't re-trigger the locale-fallback effect below.
  const accountLocaleRef = useRef<string | null>(user?.selected_locale ?? null)
  accountLocaleRef.current = user?.selected_locale ?? null
  // Run the store-default fallback only on the FIRST store load. A later refetch
  // (e.g. after saving store settings) must not re-apply it: that path already
  // owns the locale via `switchAdminLocale`, and re-applying would race that
  // PATCH and could reload before it lands. Re-armed per store (effect below) so
  // a multi-store admin still inherits each store's preferred_admin_locale.
  const localeFallbackDoneRef = useRef(false)

  const query = useQuery({
    // Keyed per store, so a slow in-flight fetch for a store the route already
    // left can never clobber the current store's cache entry.
    queryKey: [STORE_QUERY_RESOURCE, storeId],
    queryFn: () => adminClient.store.get(),
  })
  const store = query.data ?? null

  // Re-arm the one-shot fallback for each store the admin switches into.
  // biome-ignore lint/correctness/useExhaustiveDependencies: re-arm on store boundary only
  useEffect(() => {
    localeFallbackDoneRef.current = false
  }, [storeId])

  // Reconcile the admin language against this store's default — adopting it,
  // or dropping a now-stale auto-applied default — only when no account locale
  // or genuine personal choice owns it (legacy base_controller parity).
  useEffect(() => {
    if (!store || localeFallbackDoneRef.current) return

    localeFallbackDoneRef.current = true
    reconcileStoreDefaultLocale(
      store.preferred_admin_locale,
      storeId,
      accountLocaleRef.current,
      coreLocaleCodes(),
    )
  }, [store, storeId])

  const queryRefetch = query.refetch
  const refetch = useCallback(async () => {
    await queryRefetch()
  }, [queryRefetch])

  const currencies = store?.supported_currencies ?? []
  const locales = store?.supported_locales ?? []
  const availableLocales = store?.available_locales ?? []
  const defaultCurrency = store?.default_currency ?? 'USD'
  const defaultLocale = store?.default_locale ?? 'en'
  const timezone =
    store?.preferred_timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'

  return (
    <StoreContext.Provider
      value={{
        store,
        storeId,
        isLoading: query.isLoading,
        currencies,
        locales,
        availableLocales,
        defaultCurrency,
        defaultLocale,
        timezone,
        refetch,
      }}
    >
      {children}
    </StoreContext.Provider>
  )
}

export function useStore(): StoreContextValue {
  const context = useContext(StoreContext)
  if (!context) {
    throw new Error('useStore must be used within a StoreProvider')
  }
  return context
}
