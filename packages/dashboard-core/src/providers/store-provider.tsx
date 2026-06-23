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
import { coreLocaleCodes, hasStoredLocale, i18n, switchLocale } from '../lib/i18n'

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
  const localeAppliedRef = useRef(false)

  // Store-wide admin-language fallback (legacy base_controller parity). Sits
  // BELOW the personal choice in the precedence chain:
  //   user.selected_locale > stored localStorage choice > preferred_admin_locale > 'en'.
  // The auth provider applies the account's selected_locale and the top-bar/
  // profile persist explicit switches — both write the localStorage key — so we
  // only act when NO such choice exists (key absent), which distinguishes "no
  // choice yet" from an explicit 'en'. switchLocale writes the key + reloads, so
  // this is one-shot per browser; the ref additionally stops a settings-save
  // refetch from re-triggering it within the same page load.
  const applyStoreDefaultLocale = useCallback((code: string | null | undefined) => {
    if (localeAppliedRef.current) return
    localeAppliedRef.current = true
    if (!code || !coreLocaleCodes().includes(code)) return
    if (hasStoredLocale()) return
    if (code === (i18n.resolvedLanguage ?? i18n.language)) return
    switchLocale(code)
  }, [])

  // biome-ignore lint/correctness/useExhaustiveDependencies: adminClient resolves the store from the route's storeId, so we must refetch when it changes
  const fetchStore = useCallback(async () => {
    setIsLoading(true)
    try {
      const data = await adminClient.store.get()
      setStore(data)
      applyStoreDefaultLocale(data.preferred_admin_locale)
    } catch {
      setStore(null)
    } finally {
      setIsLoading(false)
    }
  }, [storeId, applyStoreDefaultLocale])

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
