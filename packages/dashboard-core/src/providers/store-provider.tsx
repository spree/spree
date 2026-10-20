import type { CurrencyCode, LocaleCode, Store } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { createContext, type ReactNode, useContext, useEffect, useMemo, useRef } from 'react'
import { adminClient } from '../client'
import { useAuth } from '../hooks/use-auth'
import { coreLocaleCodes, reconcileStoreDefaultLocale } from '../lib/i18n'
import { listAllMarkets, marketLocalization, STORE_CONFIG_STALE_TIME } from '../lib/store-config'

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
  /** Currencies of the store's markets, the default market's first. */
  currencies: CurrencyCode[]
  /** Languages the store's markets offer — what content is translated into. */
  locales: LocaleCode[]
  /** Every locale a merchant may translate content into — the full canonical
   *  set, independent of which locales the store currently uses. Drives locale
   *  pickers so a new locale can always be added. */
  availableLocales: LocaleCode[]
  /** The default market's currency. */
  defaultCurrency: CurrencyCode
  /** The default market's language. */
  defaultLocale: LocaleCode
  /** ISO country the store sells from — used to pre-fill new address forms. */
  defaultCountry: string
  /** IANA timezone for the store (e.g. `Europe/Berlin`). Falls back to the
   *  browser's resolved timezone when the store hasn't loaded yet, or when
   *  the store's preference is not a name this platform recognizes. */
  timezone: string
  refetch: () => Promise<unknown>
}

const browserTimezone = () => Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'

/** The store's zone when it is an IANA name the platform knows, else the browser's. */
function resolveTimezone(preferred: string | null | undefined): string {
  if (!preferred) return browserTimezone()
  try {
    Intl.DateTimeFormat('en-US', { timeZone: preferred })
    return preferred
  } catch {
    return browserTimezone()
  }
}

const StoreContext = createContext<StoreContextValue | null>(null)

export function StoreProvider({ storeId, children }: { storeId: string; children: ReactNode }) {
  const { user } = useAuth()

  // Read the account locale through a ref so a `user` identity change (frequent —
  // every auth update) doesn't re-trigger the locale-fallback effect below.
  const accountLocaleRef = useRef<string | null>(user?.selected_locale ?? null)
  accountLocaleRef.current = user?.selected_locale ?? null
  // Run the store-default fallback only on the FIRST load of each store. A
  // later refetch (e.g. after saving store settings) must not re-apply it:
  // that path already owns the locale via `switchAdminLocale`, and re-applying
  // would race that PATCH and could reload before it lands. Tracking the
  // storeId it last ran for re-arms it per store, so a multi-store admin still
  // inherits each store's admin_locale.
  const localeFallbackStoreRef = useRef<string | null>(null)

  const query = useQuery({
    // Keyed per store, so a slow in-flight fetch for a store the route already
    // left can never clobber the current store's cache entry.
    queryKey: [STORE_QUERY_RESOURCE, storeId],
    queryFn: () => adminClient.store.get(),
  })
  const store = query.data ?? null

  // Same key and request as the dashboard's market list, so the shell and every
  // market picker share one cached fetch that market writes invalidate.
  const marketsQuery = useQuery({
    queryKey: ['markets', storeId, 'all'],
    queryFn: listAllMarkets,
    staleTime: STORE_CONFIG_STALE_TIME,
  })
  const localization = useMemo(
    () => marketLocalization(marketsQuery.data?.data ?? []),
    [marketsQuery.data],
  )

  // Reconcile the admin language against this store's default — adopting it,
  // or dropping a now-stale auto-applied default — only when no account locale
  // or genuine personal choice owns it (legacy base_controller parity).
  useEffect(() => {
    if (!store || localeFallbackStoreRef.current === storeId) return

    localeFallbackStoreRef.current = storeId
    reconcileStoreDefaultLocale(
      store.admin_locale,
      storeId,
      accountLocaleRef.current,
      coreLocaleCodes(),
    )
  }, [store, storeId])

  const { currencies, locales } = localization
  const availableLocales = store?.available_locales ?? []
  const defaultCurrency = localization.defaultCurrency ?? 'USD'
  const defaultLocale = localization.defaultLocale ?? 'en'
  const defaultCountry = store?.default_country_code ?? ''
  // A store's zone preference defaults to the host app's `Time.zone.name`,
  // which may be a Rails name ("Eastern Time (US & Canada)") that Intl and
  // date-fns-tz reject — falling back keeps every date control working.
  const timezone = resolveTimezone(store?.timezone)

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
        defaultCountry,
        timezone,
        refetch: query.refetch,
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

/**
 * The store context if a `StoreProvider` is mounted, else `null`.
 *
 * For code that runs in more than one panel. The operator's dashboard always
 * has a store; the seller panel has none — its tenant is a seller, and the
 * store is derived server-side. Shared pieces (the nav visibility context)
 * take the store when it is there and carry on when it is not, rather than
 * forcing every panel to mount a provider for a concept it does not have.
 */
export function useOptionalStore(): StoreContextValue | null {
  return useContext(StoreContext)
}
