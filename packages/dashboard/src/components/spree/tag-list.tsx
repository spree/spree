import { Badge } from '@/components/ui/badge'

interface TagListProps {
  tags: string[] | null | undefined
  /** Rendered when there are no tags. Defaults to em-dash to match other empty cells. */
  empty?: string
}

/**
 * Renders a list of tag names as small secondary badges, wrapping when the
 * column is narrow. Used as the default cell renderer for the `tags` column
 * on resource tables that expose taggable resources (products, customers,
 * orders).
 */
export function TagList({ tags, empty = '—' }: TagListProps) {
  if (!tags || tags.length === 0) return <>{empty}</>
  return (
    <div className="flex flex-wrap gap-1">
      {tags.map((tag) => (
        <Badge key={tag} variant="secondary">
          {tag}
        </Badge>
      ))}
    </div>
  )
}
