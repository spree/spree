import { Avatar, AvatarFallback, cn } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'

function initials(name: string | null | undefined, email: string | null | undefined) {
  const parts = (name ?? '').trim().split(/\s+/).filter(Boolean)
  if (parts.length > 0) {
    return parts
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase()
  }
  return (email ?? '?').slice(0, 1).toUpperCase()
}

/**
 * A person, the same way everywhere: an initials avatar, their name, and
 * their email under it — or just the email when there is no name. Customers,
 * company members, seller team members and invitations all render through it.
 *
 * Given `link`, the whole block is the link, never the name alone: a link on
 * one line of a multi-line record is a small target and leaves the rest of
 * the record looking clickable but dead.
 */
export function PersonIdentity({
  name,
  email,
  link,
  size = 'default',
  className,
}: {
  name?: string | null
  email?: string | null
  /** Makes the whole block — avatar, name and email — a link. */
  link?: { to: string; params: Record<string, string> }
  size?: 'default' | 'sm'
  className?: string
}) {
  const primary = name?.trim() || email || ''
  const body = (
    <>
      <Avatar size={size === 'sm' ? 'sm' : 'default'}>
        <AvatarFallback className="bg-muted text-muted-foreground text-xs">
          {initials(name, email)}
        </AvatarFallback>
      </Avatar>
      <span className="flex min-w-0 flex-col text-sm">
        <span className="truncate font-medium">{primary}</span>
        {name?.trim() && email && (
          <span className="truncate text-muted-foreground text-xs">{email}</span>
        )}
      </span>
    </>
  )
  const layout = cn('flex min-w-0 items-center gap-3', size === 'sm' && 'gap-2', className)

  if (link) {
    return (
      <Link
        to={link.to}
        params={link.params}
        className={cn(
          layout,
          'rounded-md text-foreground no-underline outline-none focus-visible:shadow-field-focus',
        )}
      >
        {body}
      </Link>
    )
  }
  return <span className={layout}>{body}</span>
}
