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
import { applyStoreDefaultLocale, canApplyStoreDefaultLocale, coreLocaleCodes } from '../lib/i18n'

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

  const fetchStore = useCallback(async () => {
    setIsLoading(true)
    let data: Store | null = null
    try {
      data = await adminClient.store.get()
      setStore(data)
    } catch {
      setStore(null)
    } finally {
      setIsLoading(false)
    }
    // Outside the try: a thrown storage write in the locale fallback must not be
    // mistaken for a failed fetch and null a store that loaded successfully. The
    // fallback inherits the store's admin language only when the admin has no
    // account locale and no genuine personal choice (legacy base_controller
    // parity); an auto-applied default from another store is superseded here.
    if (data && !localeFallbackDoneRef.current) {
      localeFallbackDoneRef.current = true
      if (canApplyStoreDefaultLocale(accountLocaleRef.current, storeId)) {
        applyStoreDefaultLocale(data.preferred_admin_locale, storeId, coreLocaleCodes())
      }
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
