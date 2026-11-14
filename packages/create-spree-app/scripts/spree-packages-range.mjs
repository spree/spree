import { gemVersion, majorFloorRange, npmVersion } from '../../../scripts/version-packages.mjs'

/**
 * The range a new project declares for the packages that carry the Spree
 * version, such as `@spree/docs`: the whole major of the Spree release this
 * build ships with (`^6.0.0-0`), the same range the dashboard templates use.
 * Injected at build time (tsup) and test time (vitest).
 *
 * @returns {string}
 */
export function spreePackagesRange() {
  return majorFloorRange(npmVersion(gemVersion()))
}
