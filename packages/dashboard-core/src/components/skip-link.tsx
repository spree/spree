import { useTranslation } from 'react-i18next'

/**
 * "Skip to content", the first thing in the tab order.
 *
 * The sidebar carries thirty-odd links, and they precede the page on every
 * route. Without this a keyboard user tabs through all of them again after
 * each navigation before reaching what they came for.
 *
 * Visible only while focused: it is a keyboard affordance, and a pointer user
 * has no use for it. It stays in the DOM and in the tab order at all times
 * though — `display: none` or `hidden` would take it out of both, which is the
 * usual way this control ends up doing nothing.
 */
export function SkipLink({ targetId = 'main-content' }: { targetId?: string }) {
  const { t } = useTranslation()

  return (
    <a
      href={`#${targetId}`}
      className={[
        // Off-screen until focused, rather than hidden: reachable by Tab,
        // invisible to everyone else.
        'sr-only',
        'focus-visible:not-sr-only focus-visible:fixed focus-visible:top-3 focus-visible:left-3',
        'focus-visible:z-50 focus-visible:rounded-lg focus-visible:bg-card',
        'focus-visible:px-4 focus-visible:py-2 focus-visible:text-sm focus-visible:font-medium',
        'focus-visible:text-foreground focus-visible:shadow-md',
        'focus-visible:border focus-visible:border-border-control',
        'focus-visible:outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
      ].join(' ')}
    >
      {t('admin.common.skip_to_content')}
    </a>
  )
}
