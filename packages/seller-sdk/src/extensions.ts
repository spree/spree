import { defineExtension, type Extension, type ExtensionContext } from '@spree/sdk-core'

/**
 * A namespace a package adds to the Seller client with `client.extend()`.
 * Its calls go to `/api/v3/seller`.
 */
export type SellerExtension<Name extends string = string, Namespace = unknown> = Extension<
  'seller',
  Name,
  Namespace
>

/**
 * Defines an extension of the Seller client, for a package that ships a client
 * for its own Seller API endpoints:
 *
 * ```ts
 * export const quotes = defineSellerExtension('quotes', ({ request }) => ({
 *   get: (id: string) => request<Quote>('GET', `/quotes/${id}`),
 * }))
 *
 * const client = createSellerClient({ ... }).extend(quotes)
 * await client.quotes.get('quote_1')
 * ```
 *
 * @param name the property it adds to the client
 * @param build returns the namespace, given the client's own request function
 */
export function defineSellerExtension<Name extends string, Namespace>(
  name: Name,
  build: (context: ExtensionContext) => Namespace,
): SellerExtension<Name, Namespace> {
  return defineExtension('seller', name, build)
}
