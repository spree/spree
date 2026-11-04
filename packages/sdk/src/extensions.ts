import { defineExtension, type Extension, type ExtensionContext } from '@spree/sdk-core'

/**
 * A namespace a package adds to the Store client with `client.extend()`.
 * Its calls go to `/api/v3/store`.
 */
export type StoreExtension<Name extends string = string, Namespace = unknown> = Extension<
  'store',
  Name,
  Namespace
>

/**
 * Defines an extension of the Store client, for a package that ships a client
 * for its own Store API endpoints:
 *
 * ```ts
 * export const quotes = defineStoreExtension('quotes', ({ request }) => ({
 *   get: (id: string) => request<Quote>('GET', `/quotes/${id}`),
 * }))
 *
 * const client = createClient({ ... }).extend(quotes)
 * await client.quotes.get('quote_1')
 * ```
 *
 * @param name the property it adds to the client
 * @param build returns the namespace, given the client's own request function
 */
export function defineStoreExtension<Name extends string, Namespace>(
  name: Name,
  build: (context: ExtensionContext) => Namespace,
): StoreExtension<Name, Namespace> {
  return defineExtension('store', name, build)
}
