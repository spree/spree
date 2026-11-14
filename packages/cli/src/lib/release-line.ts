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

function compareIdentifiers(left: string, right: string): number {
  const leftNumeric = /^\d+$/.test(left)
  const rightNumeric = /^\d+$/.test(right)
  if (leftNumeric && rightNumeric) return Number(left) - Number(right)
  if (leftNumeric !== rightNumeric) return leftNumeric ? -1 : 1
  return left < right ? -1 : left > right ? 1 : 0
}

/**
 * Whether one exact version sorts before another under semver precedence: the
 * release numbers first, then a prerelease (`6.0.0-rc.7`) before its release,
 * then prerelease identifiers one by one.
 */
export function isOlderVersion(version: string, than: string): boolean {
  const [leftRelease, leftPrerelease] = splitVersion(version)
  const [rightRelease, rightPrerelease] = splitVersion(than)
  for (let index = 0; index < 3; index++) {
    const difference = leftRelease[index] - rightRelease[index]
    if (difference !== 0) return difference < 0
  }
  if (leftPrerelease.length === 0 || rightPrerelease.length === 0) {
    return leftPrerelease.length > rightPrerelease.length
  }
  for (let index = 0; index < Math.min(leftPrerelease.length, rightPrerelease.length); index++) {
    const difference = compareIdentifiers(leftPrerelease[index], rightPrerelease[index])
    if (difference !== 0) return difference < 0
  }
  return leftPrerelease.length < rightPrerelease.length
}

function splitVersion(version: string): [number[], string[]] {
  const [release, ...prerelease] = version.split('-')
  const identifiers = prerelease.join('-')
  return [release.split('.').map(Number), identifiers ? identifiers.split('.') : []]
}
