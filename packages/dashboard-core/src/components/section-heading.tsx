import { CardTitle, cn } from '@spree/dashboard-ui'
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
      <CardTitle className="min-w-0 truncate text-lg">{title}</CardTitle>
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
