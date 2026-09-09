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
  as,
}: {
  title: React.ReactNode
  description?: React.ReactNode
  /** Relative to the user guide, or a full URL for a plugin's own docs. */
  docsPath?: string
  className?: string
  /**
   * Heading element to render the title as. Defaults to a plain `div`, which
   * is right for a card sitting inside a page that already has its own
   * heading. Pass `h1` when this heading *is* the page's title — a list page
   * built from `ResourceTable` has no other one, so without it the page
   * carries no heading at all and screen-reader users lose both the document
   * outline and heading navigation.
   */
  as?: 'h1' | 'h2' | 'h3'
}) {
  const { t } = useTranslation()

  return (
    <div className={cn('flex min-w-0 flex-col gap-1', className)}>
      {/* A heading renders the same styles CardTitle carries, so a page title
          and a card title are visually identical — only the element differs.
          CardTitle is a plain div and cannot forward an element type, so the
          heading is written out rather than routed through it. */}
      {as ? (
        <Heading level={as} className="min-w-0 truncate text-lg">
          {title}
        </Heading>
      ) : (
        <CardTitle className="min-w-0 truncate text-lg">{title}</CardTitle>
      )}
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

/**
 * The title element for a `SectionHeading` that carries a heading level.
 *
 * Repeats CardTitle's own classes rather than importing them: the base
 * stylesheet sizes bare `h1`–`h6` for prose (h1 is `text-4xl`), and a heading
 * dropped into a card toolbar has to opt out of that or it renders at twice
 * the intended size. Stating the classes here also keeps the two branches of
 * `SectionHeading` visually identical by construction.
 */
function Heading({
  level,
  className,
  children,
}: {
  level: 'h1' | 'h2' | 'h3'
  className?: string
  children: React.ReactNode
}) {
  const Tag = level
  return (
    <Tag
      data-slot="card-title"
      className={cn('flex items-center gap-2 font-medium text-base', className)}
    >
      {children}
    </Tag>
  )
}
