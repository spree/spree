import { getParams } from './helpers'
import { transformListParams } from './params'
import type { RequestFn } from './request'

/** The API an extension calls, and so the client it can be added to. */
export type ExtensionApi = 'store' | 'admin' | 'seller'

/** What an extension's `build` receives from the client it is added to. */
export interface ExtensionContext {
  /**
   * The client's own request function: the same auth, store or seller
   * headers, locale defaults, retries and base path as the built-in
   * resources. Paths are relative to the client's API.
   */
  request: RequestFn
  /**
   * Turns typed list params (filters, sort, page) into the query a list
   * endpoint reads, as the built-in `list` methods do.
   */
  listParams: typeof transformListParams
  /** Turns `{ expand, fields }` into the query a read endpoint takes. */
  readParams: typeof getParams
}

/**
 * A namespace a package adds to an SDK client, made with the SDK's
 * `define…Extension`. A plain object, so a copy built against another bundle
 * of the SDK is still recognised.
 */
export interface Extension<Api extends ExtensionApi, Name extends string, Namespace> {
  readonly api: Api
  readonly name: Name
  readonly build: (context: ExtensionContext) => Namespace
}

type IsUnion<T, U = T> = T extends unknown ? ([U] extends [T] ? false : true) : never

/**
 * A client with one more extension's namespace. `extend` adds one property,
 * so a name typed as `string` or as a union adds nothing to the type rather
 * than every name it could be.
 */
export type Extended<Client, Name extends string, Namespace> = Client &
  (string extends Name
    ? unknown
    : true extends IsUnion<Name>
      ? unknown
      : { readonly [K in Name]: Namespace })

/**
 * @param api the API the extension's paths belong to
 * @param name the property it adds to the client (`quotes` → `client.quotes`)
 * @param build returns the namespace; runs once, when the extension is added
 */
export function defineExtension<Api extends ExtensionApi, Name extends string, Namespace>(
  api: Api,
  name: Name,
  build: (context: ExtensionContext) => Namespace,
): Extension<Api, Name, Namespace> {
  return Object.freeze({ api, name, build })
}

/**
 * Returns a client built on `client` with the extension's namespace added,
 * leaving `client` as it was. The new client delegates to the original, so
 * setting a token or locale on either one applies to both.
 *
 * @throws {TypeError} for an extension of another API, a name the client
 *   already has, or anything that is not an extension
 */
export function extendClient<
  Client extends object,
  Api extends ExtensionApi,
  Name extends string,
  Namespace,
>(
  client: Client,
  api: Api,
  request: RequestFn,
  extension: Extension<Api, Name, Namespace>,
): Extended<Client, Name, Namespace> {
  if (!isExtension(extension)) {
    throw new TypeError(`client.extend() takes an extension made with define…Extension()`)
  }
  const { name } = extension
  if (extension.api !== api) {
    throw new TypeError(
      `The "${name}" extension is for the ${extension.api} API, not the ${api} API`,
    )
  }
  // A `then` property would make the client a thenable, so awaiting it
  // would call the extension instead of returning the client.
  if (name === 'then') {
    throw new TypeError(`An extension cannot be named "then"`)
  }
  if (name in client) {
    throw new TypeError(
      `The client already has "${name}", so the "${name}" extension cannot be added`,
    )
  }

  const extended = Object.create(client) as Extended<Client, Name, Namespace>
  const context = { request, listParams: transformListParams, readParams: getParams }
  Object.defineProperty(extended, name, { value: extension.build(context), enumerable: true })
  return extended
}

function isExtension(value: unknown): value is Extension<ExtensionApi, string, unknown> {
  if (typeof value !== 'object' || value === null) return false
  const candidate = value as Record<string, unknown>
  return (
    typeof candidate.api === 'string' &&
    typeof candidate.name === 'string' &&
    typeof candidate.build === 'function'
  )
}
