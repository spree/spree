import { cva, type VariantProps } from 'class-variance-authority'
import type * as React from 'react'
import { cn } from '../lib/utils'
import { ImageIcon } from '../spree/icons'

const thumbnailVariants = cva(
  // The wrapper always renders, so a record without an image keeps the same
  // footprint as one with it and rows never reflow. `shrink-0` matters in the
  // flex rows these sit in — without it a long product name squashes the image.
  'flex shrink-0 items-center justify-center overflow-hidden border bg-muted text-muted-foreground [&_svg]:pointer-events-none [&_svg:not([class*=size-])]:size-4',
  {
    variants: {
      size: {
        xs: 'size-5 [&_svg:not([class*=size-])]:size-3',
        sm: 'size-8',
        md: 'size-10',
        lg: 'size-12 [&_svg:not([class*=size-])]:size-5',
      },
      shape: {
        rounded: 'rounded-md',
        square: 'rounded-none',
        circle: 'rounded-full',
      },
    },
    defaultVariants: {
      size: 'md',
      shape: 'rounded',
    },
  },
)

export interface ThumbnailProps
  extends Omit<React.ComponentProps<'div'>, 'children'>,
    VariantProps<typeof thumbnailVariants> {
  /** Image to show. When absent or failed, the fallback renders instead. */
  src?: string | null
  /**
   * Describes the image for screen readers. Leave unset when a visible label
   * sits beside the thumbnail — the image is decorative then, and repeating
   * the name makes screen readers announce it twice.
   */
  alt?: string
  /** Overrides the placeholder shown when there is no image. */
  fallback?: React.ReactNode
  /** Defer loading until the thumbnail is near the viewport. */
  loading?: 'eager' | 'lazy'
}

/**
 * A product or record image at a fixed size, falling back to a placeholder.
 *
 * Images are cropped to fill the box (`object-cover`), which suits photography.
 * Logos and artwork that must not be cropped want `Attachment` instead.
 */
export function Thumbnail({
  src,
  alt = '',
  fallback,
  size,
  shape,
  className,
  loading,
  ...props
}: ThumbnailProps) {
  return (
    <div
      data-slot="thumbnail"
      className={cn(thumbnailVariants({ size, shape }), className)}
      {...props}
    >
      {src ? (
        <img src={src} alt={alt} loading={loading} className="size-full object-cover" />
      ) : (
        (fallback ?? <ImageIcon />)
      )}
    </div>
  )
}

export { thumbnailVariants }
