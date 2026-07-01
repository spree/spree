import { Avatar as AvatarPrimitive } from '@base-ui/react/avatar'
import * as React from 'react'

import { cn } from '../lib/utils'

// Deterministic "Vercel-style" dithered avatar. A seed-derived hue picks two
// tones; a linear density gradient at a seed-random angle is quantized with a
// 4×4 Bayer matrix into an ordered-dither pixel field. Same seed → same art,
// with no dependency and nothing persisted.
const DITHER_GRID = 34
const DITHER_SIZE = 200
const BAYER_4X4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
]

function hashSeed(seed: string, salt: number): number {
  let hash = 0
  const input = `${seed}:${salt}`
  for (let i = 0; i < input.length; i++) {
    hash = (hash << 5) - hash + input.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash)
}

function hslToHex(h: number, s: number, l: number): string {
  const sN = s / 100
  const lN = l / 100
  const k = (n: number) => (n + h / 30) % 12
  const a = sN * Math.min(lN, 1 - lN)
  const f = (n: number) => lN - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)))
  const toHex = (v: number) =>
    Math.round(v * 255)
      .toString(16)
      .padStart(2, '0')
  return `#${toHex(f(0))}${toHex(f(8))}${toHex(f(4))}`
}

/**
 * Builds the SVG primitives for a seeded dithered avatar: the background `fill`,
 * the dither `stroke`, and the run-length-encoded `path` (+ its `transform`).
 */
export function ditherAvatar(seed: string): {
  fill: string
  stroke: string
  transform: string
  d: string
} {
  const hue = hashSeed(seed, 0) % 360
  const angle = (hashSeed(seed, 1) % 360) * (Math.PI / 180)
  const offset = ((hashSeed(seed, 2) % 100) / 100) * 0.4 - 0.2
  const cosA = Math.cos(angle)
  const sinA = Math.sin(angle)

  const parts: string[] = []
  for (let y = 0; y < DITHER_GRID; y++) {
    let segStart = -1
    for (let x = 0; x <= DITHER_GRID; x++) {
      let on = false
      if (x < DITHER_GRID) {
        const nx = (x / (DITHER_GRID - 1)) * 2 - 1
        const ny = (y / (DITHER_GRID - 1)) * 2 - 1
        const density = Math.max(0, Math.min(1, (nx * cosA + ny * sinA + 1 + offset) / 2))
        on = density >= BAYER_4X4[y % 4][x % 4] / 16
      }
      if (on && segStart === -1) segStart = x
      else if (!on && segStart !== -1) {
        parts.push(`M${segStart} ${y}h${x - segStart}`)
        segStart = -1
      }
    }
  }

  const scale = DITHER_SIZE / DITHER_GRID
  const half = DITHER_GRID / 2
  return {
    fill: hslToHex(hue, 85, 30),
    stroke: hslToHex(hue, 90, 65),
    transform: `translate(${DITHER_SIZE / 2},${DITHER_SIZE / 2})scale(${scale})translate(-${half},-${half})`,
    d: parts.join(''),
  }
}

function DitherAvatar({ seed }: { seed: string }) {
  const { fill, stroke, transform, d } = React.useMemo(() => ditherAvatar(seed || '?'), [seed])
  return (
    <svg
      viewBox={`0 0 ${DITHER_SIZE} ${DITHER_SIZE}`}
      width="100%"
      height="100%"
      xmlns="http://www.w3.org/2000/svg"
      shapeRendering="crispEdges"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
      className="size-full"
    >
      <rect width={DITHER_SIZE} height={DITHER_SIZE} fill={fill} />
      <path fill="none" stroke={stroke} transform={transform} d={d} />
    </svg>
  )
}

function Avatar({
  className,
  size = 'default',
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Root> & {
  size?: 'default' | 'sm' | 'lg'
}) {
  return (
    <AvatarPrimitive.Root
      data-slot="avatar"
      data-size={size}
      className={cn(
        'group/avatar relative flex size-8 shrink-0 rounded-full select-none after:absolute after:inset-0 after:rounded-full after:border after:border-border after:mix-blend-darken data-[size=lg]:size-10 data-[size=sm]:size-6 dark:after:mix-blend-lighten',
        className,
      )}
      {...props}
    />
  )
}

function AvatarImage({ className, ...props }: React.ComponentProps<typeof AvatarPrimitive.Image>) {
  return (
    <AvatarPrimitive.Image
      data-slot="avatar-image"
      className={cn('aspect-square size-full rounded-full object-cover', className)}
      {...props}
    />
  )
}

/**
 * Avatar fallback shown when no image is available. Renders a deterministic
 * dithered avatar generated from `seed` (falls back to string `children`, e.g.
 * initials, when no seed is given). The generated art is decorative — provide a
 * real image via `AvatarImage` when one exists.
 */
function AvatarFallback({
  className,
  seed,
  children,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Fallback> & { seed?: string }) {
  const avatarSeed = seed ?? (typeof children === 'string' ? children : '')
  return (
    <AvatarPrimitive.Fallback
      data-slot="avatar-fallback"
      className={cn('size-full overflow-hidden rounded-full', className)}
      {...props}
    >
      <DitherAvatar seed={avatarSeed} />
    </AvatarPrimitive.Fallback>
  )
}

function AvatarBadge({ className, ...props }: React.ComponentProps<'span'>) {
  return (
    <span
      data-slot="avatar-badge"
      className={cn(
        'absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-lg bg-primary text-primary-foreground bg-blend-color ring-2 ring-background select-none',
        'group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden',
        'group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2',
        'group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2',
        className,
      )}
      {...props}
    />
  )
}

function AvatarGroup({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="avatar-group"
      className={cn(
        'group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background',
        className,
      )}
      {...props}
    />
  )
}

function AvatarGroupCount({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="avatar-group-count"
      className={cn(
        'relative flex size-8 shrink-0 items-center justify-center rounded-lg bg-muted text-sm text-muted-foreground ring-2 ring-background group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3',
        className,
      )}
      {...props}
    />
  )
}

export { Avatar, AvatarBadge, AvatarFallback, AvatarGroup, AvatarGroupCount, AvatarImage }
