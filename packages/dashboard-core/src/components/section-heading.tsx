import { cn } from '@spree/dashboard-ui'
import { ExternalLinkIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { docsUrl } from '../lib/docs'

/**
 * A card's title with an optional line under it saying what the list is for,
 * and a link to the documentation for the feature.
 *
 * Worth writing for anything a merchant meets for the first time — catalogs,
 * price lists, transfers — and worth leaving off a list that explains itself.
 * `ResourceTable` renders this from the table definition; hand-built cards use
 * it directly so both read the same.
 */
export function SectionHeading({
  title,
  description,
  docsPath,
  className,
}: {
  title: React.ReactNode
  description?: React.ReactNode
  /** Relative to the user guide, or a full URL for a plugin's own docs. */
  docsPath?: string
  className?: string
}) {
  const { t } = useTranslation()

  return (
    <div className={cn('flex min-w-0 flex-col gap-1', className)}>
      {/* A real heading element, not a styled div. This is the screen's
          title on every list page, so a screen reader needs it as a landmark
          and an assertion by role has something to find. `CardTitle` stays a
          div for the many cards that are genuinely not the page's heading. */}
      <h1
        data-slot="card-title"
        className="flex min-w-0 items-center gap-2 truncate font-medium text-lg"
      >
        {title}
      </h1>
      {description && (
        <p className="text-muted-foreground text-sm">
          {description}
          {docsPath && (
            <>
              {' '}
              <a
                href={docsUrl(docsPath)}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-0.5 text-link hover:text-link-hover"
              >
                {t('admin.common.learn_more')}
                <ExternalLinkIcon className="size-3" />
              </a>
            </>
          )}
        </p>
      )}
    </div>
  )
}
