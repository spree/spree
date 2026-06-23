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
import { coreLocaleCodes, hasStoredLocale, i18n, switchLocale } from '../lib/i18n'

// Store-wide admin-language fallback (legacy base_controller parity). Sits BELOW
// the personal choice in the precedence chain:
//   account selected_locale > stored localStorage choice > preferred_admin_locale > 'en'.
// We only act when the admin has made NO personal choice: neither an account
// `selected_locale` nor a stored localStorage key (the latter distinguishes "no
// choice yet" from an explicit 'en'). The account check is independent of
// localStorage because the auth provider skips writing the key when the account
// locale already matches the booted language. switchLocale writes the key +
// reloads, so it's one-shot: a later settings-save refetch sees the key and bows out.
function applyStoreDefaultLocale(
  code: string | null | undefined,
  accountLocale: string | null,
): void {
  if (!code || !coreLocaleCodes().includes(code)) return
  if (accountLocale || hasStoredLocale()) return
  if (code === (i18n.resolvedLanguage ?? i18n.language)) return
  switchLocale(code)
}

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

  // biome-ignore lint/correctness/useExhaustiveDependencies: adminClient resolves the store from the route's storeId, so we must refetch when it changes
  const fetchStore = useCallback(async () => {
    setIsLoading(true)
    try {
      const data = await adminClient.store.get()
      setStore(data)
      applyStoreDefaultLocale(data.preferred_admin_locale, accountLocaleRef.current)
    } catch {
      setStore(null)
    } finally {
      setIsLoading(false)
    }
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
