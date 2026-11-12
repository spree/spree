import type { JsonValueLinkResolver } from '@spree/dashboard-ui/spree/json-preview-drawer'
import { createContext, type ReactNode, useContext } from 'react'

const JsonLinkResolverContext = createContext<JsonValueLinkResolver | undefined>(undefined)

/**
 * Supplies the resolver every "View as JSON" drawer uses to turn IDs in a
 * payload into links. The admin dashboard mounts it with its prefixed-ID
 * routes; a panel that mounts none gets plain, unlinked JSON.
 */
export function JsonLinkResolverProvider({
  resolveLink,
  children,
}: {
  resolveLink: JsonValueLinkResolver
  children: ReactNode
}) {
  return (
    <JsonLinkResolverContext.Provider value={resolveLink}>
      {children}
    </JsonLinkResolverContext.Provider>
  )
}

export function useJsonLinkResolver(): JsonValueLinkResolver | undefined {
  return useContext(JsonLinkResolverContext)
}
