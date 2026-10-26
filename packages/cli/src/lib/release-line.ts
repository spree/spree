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

/**
 * The npm spelling of a Spree gem version, as `scripts/version-packages.mjs`
 * publishes it: `6.0.0.rc7` → `6.0.0-rc.7`. Undefined for anything else.
 */
export function npmVersionOf(gemVersion: string): string | undefined {
  const match = gemVersion.match(/^(\d+\.\d+\.\d+)(?:\.([a-z]+)(\d*))?$/)
  if (!match) return undefined
  const [, release, label, number] = match
  if (!label) return release
  return number ? `${release}-${label}.${number}` : `${release}-${label}`
}

/**
 * The release line for the Spree version a project's server runs, so the
 * packages follow the server even when this CLI was built for an earlier
 * release. A server older than the line this CLI knows (Spree 5.x, before the
 * packages shared its version) moves nothing; a version that cannot be read
 * keeps the built-in line.
 *
 * @param gemVersion the installed `spree_core` version, e.g. `6.0.0.rc8`
 * @param line the line this CLI was built with
 */
export function releaseLineFor(gemVersion: string, line: ReleaseLine = RELEASE_LINE): ReleaseLine {
  const version = npmVersionOf(gemVersion)
  if (!version) return line
  const major = (value: string) => Number(value.split('.')[0])
  if (major(version) < major(line.version)) return { packages: [], version }
  return { packages: line.packages, version }
}
