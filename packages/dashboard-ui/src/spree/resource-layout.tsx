import type { ReactNode } from 'react'

interface ResourceLayoutProps {
  /** Rendered above the two columns. Typically <PageHeader />. */
  header?: ReactNode
  /** Left column content (8/12 on lg+). */
  main: ReactNode
  /** Right column content (4/12 on lg+). Optional — when omitted, main spans full width. */
  sidebar?: ReactNode
}

/**
 * Standard detail-page scaffold: header above, two columns below (8/4 on lg+,
 * stacked under). Replaces the ad-hoc grid duplicated in product/order detail
 * pages and the legacy `_edit_resource.html.erb` skeleton.
 */
export function ResourceLayout({ header, main, sidebar }: ResourceLayoutProps) {
  return (
    <div className="flex flex-col gap-6">
      {header}
      {sidebar ? (
        <div className="grid grid-cols-12 gap-6">
          <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">{main}</div>
          <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">{sidebar}</div>
        </div>
      ) : (
        <div className="flex flex-col gap-6">{main}</div>
      )}
    </div>
  )
}
