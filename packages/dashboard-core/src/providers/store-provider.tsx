import type { Store } from '@spree/admin-sdk'
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react'
import { adminClient } from '../client'
import { useAuth } from '../hooks/use-auth'
import { coreLocaleCodes, reconcileStoreDefaultLocale } from '../lib/i18n'

interface StoreContextValue {
  store: Store | null
  storeId: string
  isLoading: boolean
  currencies: string[]
  locales: string[]
  defaultCurrency: string
  defaultLocale: string
  /** IANA timezone for the store (e.g. `Europe/Berlin`). Falls back to the
   *  browser's resolved timezone when the store hasn't loaded yet. */
  timezone: string
  refetch: () => Promise<void>
}

const StoreContext = createContext<StoreContextValue | null>(null)

export function StoreProvider({ storeId, children }: { storeId: string; children: ReactNode }) {
  const [store, setStore] = useState<Store | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const { user } = useAuth()

  // Read the account locale through a ref so a `user` identity change (frequent —
  // every auth update) doesn't re-key `fetchStore` and refetch the store.
  const accountLocaleRef = useRef<string | null>(user?.selected_locale ?? null)
  accountLocaleRef.current = user?.selected_locale ?? null
  // Run the store-default fallback only on the FIRST store load. A later refetch
  // (e.g. after saving store settings) must not re-apply it: that path already
  // owns the locale via `switchAdminLocale`, and re-applying would race that
  // PATCH and could reload before it lands. Re-armed per store (effect below) so
  // a multi-store admin still inherits each store's preferred_admin_locale.
  const localeFallbackDoneRef = useRef(false)
  // Latest requested storeId, so a slow in-flight fetch that resolves after the
  // route already moved to another store is dropped instead of clobbering the
  // current store's state and one-shot locale fallback.
  const latestStoreIdRef = useRef(storeId)
  latestStoreIdRef.current = storeId

  const fetchStore = useCallback(async () => {
    setIsLoading(true)
    let data: Store | null = null
    try {
      const result = await adminClient.store.get()
      // Drop a stale response: the route moved on while this was in flight.
      if (latestStoreIdRef.current !== storeId) return
      data = result
      setStore(data)
    } catch {
      if (latestStoreIdRef.current !== storeId) return
      setStore(null)
    } finally {
      if (latestStoreIdRef.current === storeId) setIsLoading(false)
    }
    // Outside the try: a thrown storage write in the locale fallback must not be
    // mistaken for a failed fetch and null a store that loaded successfully.
    // Reconcile the admin language against this store's default — adopting it,
    // or dropping a now-stale auto-applied default — only when no account locale
    // or genuine personal choice owns it (legacy base_controller parity).
    if (data && !localeFallbackDoneRef.current) {
      localeFallbackDoneRef.current = true
      reconcileStoreDefaultLocale(
        data.preferred_admin_locale,
        storeId,
        accountLocaleRef.current,
        coreLocaleCodes(),
      )
    }
  }, [storeId])

  // Re-arm the one-shot fallback for each store the admin switches into.
  // biome-ignore lint/correctness/useExhaustiveDependencies: re-arm on store boundary only
  useEffect(() => {
    localeFallbackDoneRef.current = false
  }, [storeId])

  useEffect(() => {
    fetchStore()
  }, [fetchStore])

  const currencies = store?.supported_currencies ?? []
  const locales = store?.supported_locales ?? []
  const defaultCurrency = store?.default_currency ?? 'USD'
  const defaultLocale = store?.default_locale ?? 'en'
  const timezone =
    store?.preferred_timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'

  return (
    <StoreContext.Provider
      value={{
        store,
        storeId,
        isLoading,
        currencies,
        locales,
        defaultCurrency,
        defaultLocale,
        timezone,
        refetch: fetchStore,
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
