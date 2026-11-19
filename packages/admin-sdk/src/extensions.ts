import { defineExtension, type Extension, type ExtensionContext } from '@spree/sdk-core'

/**
 * A namespace a package adds to the Admin client with `client.extend()`.
 * Its calls go to `/api/v3/admin`.
 */
export type AdminExtension<Name extends string = string, Namespace = unknown> = Extension<
  'admin',
  Name,
  Namespace
>

/**
 * Defines an extension of the Admin client, for a package that ships a client
 * for its own Admin API endpoints:
 *
 * ```ts
 * export const quotes = defineAdminExtension('quotes', ({ request }) => ({
 *   get: (id: string) => request<Quote>('GET', `/quotes/${id}`),
 * }))
 *
 * const client = createAdminClient({ ... }).extend(quotes)
 * await client.quotes.get('quote_1')
 * ```
 *
 * @param name the property it adds to the client
 * @param build returns the namespace, given the client's own request function
 */
export function defineAdminExtension<Name extends string, Namespace>(
  name: Name,
  build: (context: ExtensionContext) => Namespace,
): AdminExtension<Name, Namespace> {
  return defineExtension('admin', name, build)
}
