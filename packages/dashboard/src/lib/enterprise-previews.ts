import type { SubjectName } from '@spree/dashboard-core'
import type { LucideIcon } from 'lucide-react'
import { useSyncExternalStore } from 'react'

export const SPREE_ENTERPRISE_URL = 'https://spreecommerce.org/enterprise/'

/**
 * Previews are on unless the host turns them off at build time with
 * `VITE_SPREE_ENTERPRISE_PREVIEWS=false` — an agency handing a dashboard to a
 * client may not want Spree's paid tier advertised in it.
 */
export const ENTERPRISE_PREVIEWS_ENABLED =
  import.meta.env.VITE_SPREE_ENTERPRISE_PREVIEWS !== 'false'

/**
 * Where a preview's entry sits: under a main sidebar section, or in a
 * settings group.
 */
export type EnterprisePreviewPlacement =
  | { nav: string; position: number }
  | { settingsGroup: string; position: number }

/**
 * A Spree Enterprise feature that open-source Spree shows as a preview page,
 * at the place in the dashboard where the real page appears once Enterprise
 * is installed.
 */
export interface EnterprisePreview {
  /**
   * Nav and route key. Spree Enterprise registers its real page under the
   * same key once it has removed the preview.
   */
  key: string
  /** Translation segment under `admin.enterprise.previews`. */
  id: string
  /** Path relative to `/$storeId` — or to `/$storeId/settings` for a settings entry. */
  path: string
  placement: EnterprisePreviewPlacement
  /** Staff who can't read this subject don't see the entry or the page. */
  subject: SubjectName
  icon: LucideIcon
  /** Translation keys under `admin.enterprise.previews.<id>.benefits`. */
  benefits: string[]
  /** Translation keys under `admin.enterprise.previews.<id>.steps`, in order. */
  steps: string[]
}

const active = new Map<string, EnterprisePreview>()
const listeners = new Set<() => void>()
let snapshot: ReadonlyMap<string, EnterprisePreview> = new Map()
const removers = new Map<string, () => void>()

function subscribe(listener: () => void) {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function getSnapshot() {
  return snapshot
}

function notify() {
  snapshot = new Map(active)
  for (const listener of listeners) listener()
}

/**
 * The registered previews. Spree Enterprise removes each one it ships, which
 * takes down the sidebar entry, the page, and every in-context note pointing
 * at it:
 *
 *     enterprisePreviews.remove('orders.quotes')
 */
export const enterprisePreviews = {
  /** @internal Used by the dashboard's own registration. */
  add(preview: EnterprisePreview, remove: () => void) {
    active.set(preview.key, preview)
    removers.set(preview.key, remove)
    notify()
  },
  remove(key: string) {
    if (!active.has(key)) return
    removers.get(key)?.()
    removers.delete(key)
    active.delete(key)
    notify()
  },
}

/**
 * The preview registered under `key`, or `undefined` once Spree Enterprise
 * has replaced it (or previews are switched off).
 *
 * @param key Preview key, e.g. `orders.quotes`.
 * @returns The preview, or `undefined`.
 */
export function useEnterprisePreview(key: string): EnterprisePreview | undefined {
  return useSyncExternalStore(subscribe, getSnapshot).get(key)
}

/**
 * The preview page's URL in a store.
 *
 * @param preview The preview.
 * @param storeId Store prefixed ID.
 * @returns Path starting with `/<storeId>`.
 */
export function enterprisePreviewPath(preview: EnterprisePreview, storeId: string): string {
  const prefix = 'settingsGroup' in preview.placement ? '/settings' : ''
  return `/${storeId}${prefix}${preview.path}`
}

/**
 * The Spree Enterprise page, tagged with the feature the link came from so
 * interest can be told apart without the dashboard tracking anyone.
 *
 * @param previewId Preview `id`, e.g. `quotes`.
 * @returns Absolute URL.
 */
export function enterpriseUrl(previewId?: string): string {
  if (!previewId) return SPREE_ENTERPRISE_URL
  const params = new URLSearchParams({
    utm_source: 'dashboard',
    utm_medium: 'preview',
    utm_campaign: previewId,
  })
  return `${SPREE_ENTERPRISE_URL}?${params}`
}
