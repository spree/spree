import { createContext, type ReactNode, useCallback, useContext, useEffect, useState } from 'react'
import type { Store } from '@spree/admin-sdk'
import { adminClient } from '@/client'

interface StoreContextValue {
  store: Store | null
  storeId: string
  isLoading: boolean
  refetch: () => Promise<void>
}

const StoreContext = createContext<StoreContextValue | null>(null)

export function StoreProvider({ storeId, children }: { storeId: string; children: ReactNode }) {
  const [store, setStore] = useState<Store | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  const fetchStore = useCallback(async () => {
    setIsLoading(true)
    try {
      const data = await adminClient.store.get()
      setStore(data)
    } catch {
      setStore(null)
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchStore()
  }, [storeId, fetchStore])

  return (
    <StoreContext.Provider value={{ store, storeId, isLoading, refetch: fetchStore }}>
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
