/**
 * The client registry.
 *
 * `@spree/dashboard-core` is the framework behind more than one panel: the
 * marketplace operator's dashboard talks to the Admin API, a seller's panel
 * talks to the Seller API. Those are different surfaces with different
 * credentials — a seller JWT and `X-Spree-Seller-Id` rather than a secret key
 * and a store header — so the framework cannot own either client. Each host
 * builds its own and registers it here at boot.
 *
 * Only the surface both panels share is typed. Anything admin-only
 * (`customFieldDefinitions`, `imports`, store switching) stays on the admin
 * client, imported directly by the code that needs it — typing it here would
 * promise the seller panel methods its API does not have.
 */

import type { PermissionRule } from '@spree/admin-sdk'

/** What the permission provider needs, whichever panel asked. */
export interface PanelPermissions {
  /**
   * CanCanCan rules. The seller panel returns none — its capability is the
   * key list alone — so an empty array is a valid answer, not a failure.
   */
  rules: PermissionRule[]
  keys: string[]
}

/** What every panel's client can do, whichever API it talks to. */
export interface PanelApiClient {
  auth: {
    login(params: { email: string; password: string }): Promise<PanelSession>
    refresh(): Promise<PanelSession>
    logout(): Promise<void>
    /**
     * Optional sign-in flows, because not every panel offers all of them.
     * Both panels accept invitations and reset passwords — each against its
     * own API, so the session that comes back carries the right audience and
     * the emailed link opens the right panel. First-run setup remains the
     * marketplace's own, so a seller's client leaves it undefined.
     */
    acceptInvitation?(id: string, token: string, params: unknown): Promise<PanelSession>
    resetPassword?(token: string, params: unknown): Promise<PanelSession>
    completeSetup?(params: unknown): Promise<PanelSession>
  }
  setToken(token: string): void
  onUnauthorized(handler: () => Promise<boolean>): void
  /**
   * Forgets which tenant the session was acting as — the store on the admin
   * panel, the seller on a seller's. Left set, it rides into the next
   * principal's first requests and 403s them against a tenant they may hold
   * no role on.
   */
  clearTenant?(): void
  /**
   * Reads the signed-in principal's capability. Panel-specific because the
   * two APIs answer different shapes: the admin `/me` returns CanCanCan rules
   * and keys, the seller `/me` returns keys scoped to the selected seller.
   */
  fetchPermissions(): Promise<PanelPermissions>
  /**
   * Countries (with their states) for the shared address form.
   *
   * Registered rather than imported, for the same reason as everything else
   * here: reaching for `adminClient` would make the one address form work
   * only in the operator's panel, and a seller filling in a billing address
   * would get an empty country list.
   */
  listCountries?(): Promise<{ data: PanelCountry[] }>
  /**
   * Stock locations, for the shared management page.
   *
   * Both panels manage the same records against their own branch — the
   * operator every location in the store, a seller only their own, scoped
   * server-side. `delete` is optional because a seller's API does not offer
   * it: a location holds stock levels and is named on historical
   * fulfillments, so they retire one by deactivating it.
   */
  /**
   * Exchanges blob metadata for a presigned upload URL.
   *
   * Registered rather than imported for the same reason as everything else
   * here: the shared upload field would otherwise work only in the
   * operator's panel, and a seller uploading an onboarding document would
   * get a 401 from an API they hold no key for.
   */
  createDirectUpload?(params: {
    blob: { filename: string; byte_size: number; checksum: string; content_type: string }
  }): Promise<{
    direct_upload: { url: string; headers: Record<string, string> }
    signed_id: string
  }>
  stockLocations?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelStockLocation[]; meta?: unknown }>
    get(id: string): Promise<PanelStockLocation>
    create(params: PanelStockLocationCreateParams): Promise<PanelStockLocation>
    update(id: string, params: PanelStockLocationParams): Promise<PanelStockLocation>
    delete?(id: string): Promise<void>
  }
  /**
   * The reference data the shared product form reads: the option types a
   * variant is built from, and the categories, collections and product types
   * a product is filed under.
   *
   * Registered for the same reason as everything above — the form is one set
   * of cards serving both panels, and reaching for `adminClient` inside them
   * would leave a seller with empty pickers. Each is optional: a panel that
   * offers no such picker simply does not register it, and the card hides.
   */
  optionTypes?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelOptionType[] }>
    /**
     * Naming a new option (Size, Colour) while building a variant matrix.
     * Operator-only: a seller names options inline on the variant instead,
     * so their client leaves these out and the builder hides.
     *
     * `name` and `label` are named rather than left to a loose record — they
     * are what the API requires, and a contract that did not say so would
     * push the check to a cast at the registration site.
     */
    create?(
      params: { name: string; label: string } & Record<string, unknown>,
    ): Promise<PanelOptionType>
    update?(
      id: string,
      params: { option_values?: Array<{ name: string; label: string }> } & Record<string, unknown>,
    ): Promise<PanelOptionType>
  }
  categories?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelNamedRecord[] }>
  }
  collections?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelCollection[] }>
  }
  productTypes?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelProductType[] }>
    get(id: string): Promise<PanelProductType>
  }
  /**
   * Tax category is marketplace configuration a seller does not write, so
   * their client registers none and the card that reads it hides.
   *
   * Delivery profiles are different: the marketplace defines them, but a
   * seller assigns one to their own product — it decides how their goods can
   * be shipped at all — so both panels register this one
   * (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
   */
  taxCategories?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelNamedRecord[] }>
  }
  deliveryProfiles?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelDeliveryProfile[] }>
  }
  /**
   * Headers a file download must carry beyond the bearer token.
   *
   * A download is a bare `fetch`, not an SDK call, so it bypasses whatever
   * the client normally attaches — which on the seller panel is
   * `X-Spree-Seller-Id`, and without it every Seller API request is refused
   * before the action runs. The admin panel needs none, so it registers none.
   */
  downloadHeaders?(): Record<string, string>
  /**
   * Queuing a CSV export and reading it back.
   *
   * Registered rather than imported for the same reason as everything else
   * here: the export dialog is one component serving both panels, and
   * reaching for `adminClient` inside it would make a seller's export request
   * go out against an API they hold no key for.
   *
   * Which datasets may be exported is the API's business, not this
   * contract's — each panel offers its own list, and the server refuses the
   * rest. A panel that offers no export simply registers none, and the button
   * hides.
   */
  exports?: {
    create(params: PanelExportCreateParams): Promise<PanelExport>
    get(id: string): Promise<PanelExport>
  }
  /** Removing a file already on a product. */
  deleteProductMedia?(productId: string, mediaId: string): Promise<void>
  /**
   * The store-wide media library, for placing a file already uploaded onto
   * another product. Operator-only: a seller sees their own product's files,
   * never the marketplace's library, so their client registers none and the
   * "add from library" affordance hides.
   */
  mediaLibrary?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelMediaRecord[] }>
  }
  /**
   * CSV imports, for whichever catalog this panel manages.
   *
   * Registered rather than imported for the same reason as everything else
   * here: the wizard is one component serving both panels, and reaching for
   * `adminClient` inside it would leave a seller uploading against an API
   * they hold no key for.
   *
   * Structural, not either SDK's type — the two branches serve the same
   * payload from parallel serializers, and the wizard reads only what both
   * carry. `templateUrl` and `exampleUrl` are functions rather than fixed
   * strings because each panel's endpoints live under its own branch, and the
   * download helpers take a URL rather than a resource method (they stream
   * with the caller's JWT).
   */
  imports?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelImport[]; meta?: PanelPageMeta }>
    get(id: string): Promise<PanelImport>
    create(params: PanelImportCreateParams): Promise<PanelImport>
    completeMapping(id: string, params?: PanelImportCompleteMappingParams): Promise<PanelImport>
    retryFailedRows(id: string): Promise<PanelImport>
    delete(id: string): Promise<void>
    rows: {
      list(
        importId: string,
        params?: Record<string, unknown>,
      ): Promise<{ data: PanelImportRow[]; meta?: PanelPageMeta }>
    }
    /** Which datasets this panel may import — the wizard offers no others. */
    types: readonly string[]
    /**
     * Query-key roots a finished import should mark stale, on top of the
     * defaults core invalidates.
     *
     * The pipeline writes records server-side, outside any tracked mutation,
     * so nothing else ever marks those lists stale — and each panel names its
     * lists differently (the operator's products table is keyed `products`,
     * a seller's `seller-products`). A panel that does not name its own keys
     * gets a list still serving its pre-import cache, which reads as an
     * import that silently did nothing.
     */
    invalidateKeys?: readonly string[]
    /**
     * Paths to this panel's import endpoints, relative to the API origin.
     *
     * Root-relative on purpose: `downloadFromApi` resolves them against
     * `VITE_SPREE_API_URL` and sends the JWT only when the result is that
     * origin, so a panel pointed at a different API host must set that
     * variable too (both starters feed the client and the download path from
     * it). An absolute URL to another host is safe but pointless — the token
     * is withheld and the request will not authenticate.
     */
    templateUrl(type: string): string
    exampleUrl(type: string): string
    downloadUrl(id: string): string
  }
  /**
   * The store's tag vocabulary. Operator-only: tags are tenanted to the store
   * (`acts_as_taggable_tenant :store_id`), so a seller typing a new one would
   * be writing into the marketplace's own namespace.
   */
  tags?: {
    list(params?: Record<string, unknown>): Promise<{ data: Array<{ name: string }> }>
  }
  /**
   * Currency-to-locale pairs, which is what tells a money field whether
   * `34,56` is thirty-four and a half or three thousand. The operator's
   * markets answer it; a panel that registers none falls back to the UI
   * language, the same answer the operator's hook gives for an unmatched
   * currency.
   */
  markets?: {
    list(params?: Record<string, unknown>): Promise<{ data: PanelMarket[] }>
  }
}

export interface PanelDeliveryProfile extends PanelNamedRecord {
  default?: boolean
}

/**
 * One CSV import, as the shared wizard reads it: the mapping payload while
 * `mapping`, the poll counters once processing starts.
 */
export interface PanelImport {
  id: string
  /** Human-facing identifier shown in the wizard header (`IM1001`). */
  number: string
  type: string | null
  status: string
  rows_count: number
  completed_rows_count: number
  failed_rows_count: number
  processing_errors?: string | null
  preferred_delimiter?: string
  schema_fields: Array<{ name: string; label: string; required: boolean }>
  csv_headers: string[]
  sample_row: Record<string, string | null>
  mappings: Array<{ schema_field: string; file_column: string | null; required: boolean }>
  original_filename?: string | null
  original_byte_size?: number | null
  original_file_url?: string | null
  created_at?: string
  updated_at?: string
}

/**
 * Pagination meta, as both APIs answer it. Structural for the same reason the
 * records are: the two branches serve one shape and the shared UI reads only
 * what both carry.
 */
export interface PanelPageMeta {
  count: number
  page: number
  pages: number
  from?: number
  to?: number
}

/** One row of an import — the failure report's unit. */
export interface PanelImportRow {
  id: string
  row_number: number
  status: string
  validation_errors?: string | null
  data?: Record<string, string | null>
}

export interface PanelImportCreateParams {
  type: string
  /** Signed blob id of the already direct-uploaded CSV. */
  attachment: string
  /** CSV column separator — the four both APIs accept. */
  preferred_delimiter?: PanelImportDelimiter
  results_url?: string
}

/** The column separators the import upload form offers. */
export type PanelImportDelimiter = ',' | ';' | '|' | '\t'

export interface PanelImportCompleteMappingParams {
  mappings?: Array<{ schema_field: string; file_column: string | null }>
}

/** A market, as the money fields read it. */
export interface PanelMarket {
  id: string
  currency?: string | null
  default_locale?: string | null
}

/**
 * What either panel sends to queue an export.
 *
 * `type` stays a plain string: the operator's registry and a seller's
 * allowlist are different sets, and each SDK narrows it to its own.
 */
export interface PanelExportCreateParams {
  type: string
  search_params?: Record<string, unknown>
  record_selection?: 'filtered' | 'all'
  results_url?: string
}

/**
 * An export as the dialog polls it. Structural rather than either SDK's
 * type — both serializers carry exactly this, and what only one of them adds
 * is not the dialog's business.
 */
export interface PanelExport {
  id: string
  done: boolean
  download_url?: string | null
  filename?: string | null
}

/** A library file, as the picker lists it. */
export interface PanelMediaRecord {
  id: string
  alt?: string | null
  small_url?: string | null
  original_url?: string | null
}

/** Anything the form lists by name in a picker. */
export interface PanelNamedRecord {
  id: string
  name: string
}

/**
 * A rule-based collection fills itself, so the form offers only manual ones
 * to pick from.
 */
export interface PanelCollection extends PanelNamedRecord {
  automatic?: boolean
}

/**
 * An option type as the variants builder reads it. Structural, like
 * PanelStockLocation: both serializers carry the name and its values, and
 * what only one of them adds is not the form's business.
 */
export interface PanelOptionType {
  id: string
  name: string
  label: string
  kind?: string
  position?: number
  option_values?: Array<{
    id: string
    name: string
    label: string
    position?: number
    color_code?: string | null
  }>
}

export interface PanelProductType {
  id: string
  name: string
  option_type_ids?: string[]
  /**
   * The option types picking this type will add, already named. A panel that
   * manages no option-type vocabulary (a seller's) cannot resolve
   * `option_type_ids` against a list it never loads, so its API sends the
   * labels instead and the form reads whichever it was given.
   */
  option_type_labels?: string[]
  category_ids?: string[]
  custom_field_definitions?: unknown[]
}

/**
 * A stock location as the shared page reads it.
 *
 * Structural rather than either SDK's type: the two serializers overlap on
 * everything this page shows, and the fields only one of them carries
 * (`admin_name`, `propagate_all_variants`) are optional here so the page can
 * hide what a panel does not send.
 */
export interface PanelStockLocation {
  id: string
  name: string
  admin_name?: string | null
  kind: string
  active: boolean
  default: boolean
  propagate_all_variants?: boolean
  backorderable_default?: boolean
  address1?: string | null
  address2?: string | null
  city?: string | null
  zipcode?: string | null
  phone?: string | null
  company?: string | null
  country_code?: string | null
  state_code?: string | null
  state_name?: string | null
  /** Rendered read-only in the table; either panel's serializer derives it. */
  state_text?: string | null
  pickup_enabled?: boolean
  /** Open on read — a serializer answers whatever is stored. */
  pickup_stock_policy?: string
  pickup_ready_in_minutes?: number | null
  pickup_instructions?: string | null
}

/**
 * What either panel accepts when updating one — every field optional, since
 * a caller may be writing a single toggle.
 */
export type PanelStockLocationParams = Partial<
  Omit<PanelStockLocation, 'id' | 'pickup_stock_policy'>
> & {
  /**
   * Narrowed on write where the read type is open: `kind` stays a free string
   * because plugins register their own, but the pickup policy is a fixed pair
   * the server validates, and both SDKs type it that way.
   */
  pickup_stock_policy?: 'local' | 'any'
}

/**
 * Creating one additionally requires a name, matching both APIs: a location
 * without one cannot exist, and neither SDK makes it optional.
 */
export type PanelStockLocationCreateParams = PanelStockLocationParams & { name: string }

/**
 * A country as the address form needs it. Structural, not the Admin SDK's
 * `Country`: both panels' country endpoints answer this shape, and typing
 * the wider one here would bind core to a package a seller's panel does not
 * install.
 */
export interface PanelCountry {
  iso: string
  iso3: string
  name: string
  states_required?: boolean
  zipcode_required?: boolean
  states?: Array<{ abbr: string; name: string }>
}

/** What a sign-in returns, whichever panel asked. */
export interface PanelSession {
  token: string
  // Panel-specific: an AdminUser here, the same class through the seller API.
  // Typed loosely so core does not depend on either package's user type.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  user: any
}

let registered: PanelApiClient | null = null

/**
 * Registers the client for this panel. Call once at boot, before rendering —
 * providers read it on mount.
 */
export function setApiClient(client: PanelApiClient): void {
  registered = client
}

/**
 * The registered client.
 *
 * Throws rather than returning null: a panel that renders without registering
 * one is misconfigured, and every call would otherwise fail somewhere further
 * away with a less useful message.
 */
export function getApiClient(): PanelApiClient {
  if (!registered) {
    throw new Error(
      '@spree/dashboard-core: no API client registered. Call setApiClient(client) at boot, ' +
        'before rendering the app.',
    )
  }

  return registered
}

/** Whether a client has been registered. For tests and conditional boot paths. */
export function hasApiClient(): boolean {
  return registered !== null
}
