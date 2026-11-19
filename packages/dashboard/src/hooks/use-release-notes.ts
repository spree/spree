import { useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

const RELEASES_API = 'https://api.github.com/repos/spree/spree/releases/tags/'
const STORAGE_PREFIX = 'spree-release-notes-html:'

function readStored(tag: string): string | null {
  try {
    return window.localStorage.getItem(STORAGE_PREFIX + tag)
  } catch {
    return null
  }
}

function writeStored(tag: string, notes: string) {
  try {
    window.localStorage.setItem(STORAGE_PREFIX + tag, notes)
  } catch {
    // Storage blocked: the notes are fetched again next time.
  }
}

/**
 * The notes GitHub publishes for a Spree release, as the HTML GitHub renders
 * for them.
 *
 * Fetched by the browser and kept per release in local storage: GitHub
 * allows 60 unauthenticated requests an hour per IP address, which a whole
 * office of admins shares, and published notes do not change.
 */
export function useReleaseNotes(version: string | null | undefined, enabled: boolean) {
  const tag = version ? `v${version}` : null

  return useQuery({
    queryKey: useResourceKey('release-notes', tag),
    queryFn: async () => {
      if (!tag) return ''

      const stored = readStored(tag)
      if (stored !== null) return stored

      const response = await fetch(RELEASES_API + encodeURIComponent(tag), {
        headers: { Accept: 'application/vnd.github.html+json' },
      })
      if (!response.ok) throw new Error(`GitHub answered ${response.status}`)

      const release = (await response.json()) as { body_html?: unknown }
      if (typeof release.body_html !== 'string') return ''
      writeStored(tag, release.body_html)
      return release.body_html
    },
    enabled: enabled && tag !== null,
    staleTime: Number.POSITIVE_INFINITY,
    retry: false,
  })
}
