export interface ReleaseLine {
  packages: string[]
  version: string
}

declare const __SPREE_RELEASE_LINE__: ReleaseLine

/**
 * The `@spree/*` packages released with the Spree version, and that version,
 * as of this CLI's build (see scripts/release-line.mjs).
 */
export const RELEASE_LINE: ReleaseLine = __SPREE_RELEASE_LINE__
