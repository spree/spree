import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Keeps the document title in step with the page, and announces navigation.
 *
 * A single-page app changes neither by itself. Two things follow: every browser
 * tab, history entry and bookmark reads "Spree Admin" regardless of where the
 * merchant is, and a screen reader says nothing at all when a link swaps the
 * whole page — the reader announces a title change on a document load, and the
 * SPA never performs one.
 *
 * The title is read from the page's own `<h1>` rather than declared per route:
 * there are forty-odd routes and plugins add more, so anything that has to be
 * restated in each one is a list that drifts. The `h1` is already the page's
 * name, already translated, and already carries the record's own name on a
 * detail page ("R1001" rather than a generic "Order").
 *
 * A `MutationObserver` is what makes this reliable. The heading is not in the
 * DOM on the first frame after a navigation — the route's data is still
 * loading and the pending component is showing — so reading once on a path
 * change finds either nothing or the previous page's heading.
 */
export function RouteAnnouncer({ suffix }: { suffix?: string }) {
  const { t } = useTranslation()
  const [announcement, setAnnouncement] = useState('')
  // The title as last applied, so an unchanged heading doesn't re-announce on
  // every unrelated DOM mutation.
  const lastTitle = useRef<string | null>(null)
  const appName = suffix ?? t('admin.app_name', 'Spree Admin')

  useEffect(() => {
    const sync = () => {
      const heading = document.querySelector('h1')
      const pageTitle = heading?.textContent?.trim()
      if (!pageTitle) return

      const next = `${pageTitle} · ${appName}`
      if (next === lastTitle.current) return

      lastTitle.current = next
      document.title = next
      // The heading text alone, not the full title: the app name is repeated
      // on every page and adds nothing when spoken aloud.
      setAnnouncement(pageTitle)
    }

    sync()
    const observer = new MutationObserver(sync)
    observer.observe(document.body, { subtree: true, childList: true, characterData: true })
    return () => observer.disconnect()
  }, [appName])

  return (
    <div aria-live="polite" aria-atomic="true" className="sr-only">
      {announcement}
    </div>
  )
}
