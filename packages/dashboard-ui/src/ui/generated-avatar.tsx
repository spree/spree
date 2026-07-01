import type * as React from 'react'

import { Avatar, AvatarFallback, AvatarImage } from './avatar'

// Deterministic 32-bit hash (Java String.hashCode style) so a given seed always
// maps to the same gradient across renders, sessions, and machines.
function hashSeed(seed: string): number {
  let hash = 0
  for (let i = 0; i < seed.length; i++) {
    hash = (hash << 5) - hash + seed.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash)
}

/**
 * Derives a stable, vivid two-stop gradient from a seed string. Same seed in →
 * same colors out, so a user's avatar stays consistent without persisting anything.
 */
export function gradientForSeed(seed: string): string {
  const hash = hashSeed(seed || '?')
  const hue = hash % 360
  const from = `hsl(${hue} 74% 60%)`
  const to = `hsl(${(hue + 55) % 360} 68% 46%)`
  const angle = 120 + (hash % 80)
  return `linear-gradient(${angle}deg, ${from}, ${to})`
}

/**
 * Avatar with a generated gradient background derived from `seed`. Renders `src`
 * when provided, otherwise the gradient with optional `initials` overlaid.
 */
function GeneratedAvatar({
  seed,
  initials,
  src,
  className,
  size = 'default',
  ...props
}: React.ComponentProps<typeof Avatar> & {
  seed: string
  initials?: string
  src?: string | null
}) {
  return (
    <Avatar size={size} className={className} {...props}>
      {src ? <AvatarImage src={src} /> : null}
      <AvatarFallback
        style={{ backgroundImage: gradientForSeed(seed) }}
        className="font-medium text-white"
      >
        {initials}
      </AvatarFallback>
    </Avatar>
  )
}

export { GeneratedAvatar }
