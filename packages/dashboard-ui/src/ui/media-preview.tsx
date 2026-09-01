import type * as React from 'react'
import { useTranslation } from 'react-i18next'
import { cn } from '../lib/utils'
import { FilmIcon, ImagePlusIcon } from '../spree/icons'

export interface MediaPreviewProps {
  mediaType?: 'image' | 'video' | 'external_video' | string
  /** Still image URL — the image itself, or a video's poster. */
  previewUrl?: string | null
  /** Playable file for an uploaded video. */
  videoUrl?: string | null
  /**
   * Player URL for an external video. Parsing the provider link is the
   * caller's job — the server is the authority on what is embeddable, and
   * this component only renders what it is handed.
   */
  embedUrl?: string | null
  alt?: string
  /** Normalized 0–1. Drawn as a marker over an image. */
  focalPoint?: { x: number; y: number } | null
  /** Click handler for setting the focal point; images only. */
  onFocalPointClick?: (event: React.MouseEvent<HTMLElement>) => void
  className?: string
}

/**
 * What a media row looks like, whatever its kind: an external video as its
 * provider's embed, an uploaded video as a player, an image as a picture —
 * with a focal point marker when one is set.
 *
 * Headless by the package rule: everything arrives as props, so the same
 * component serves a saved record and a form row that only has blob URLs
 * because it has not been saved yet.
 */
export function MediaPreview({
  mediaType = 'image',
  previewUrl,
  videoUrl,
  embedUrl,
  alt = '',
  focalPoint,
  onFocalPointClick,
  className = 'max-h-[60vh]',
}: MediaPreviewProps) {
  const { t } = useTranslation()

  const isImage = mediaType === 'image'

  if (mediaType === 'external_video' && embedUrl) {
    return (
      <div className="aspect-video w-full shrink-0 overflow-hidden rounded-lg border border-border bg-black">
        <iframe
          src={embedUrl}
          title={alt || t('admin.components.media_preview.video_title')}
          allowFullScreen
          className="size-full"
        />
      </div>
    )
  }

  if (mediaType === 'video' && videoUrl) {
    return (
      // biome-ignore lint/a11y/useMediaCaption: merchant-supplied footage has no track to offer
      <video
        src={videoUrl}
        poster={previewUrl ?? undefined}
        controls
        playsInline
        preload="metadata"
        className={cn('w-full shrink-0 rounded-lg bg-black', className)}
      />
    )
  }

  const canSetFocalPoint = isImage && !!previewUrl && !!onFocalPointClick

  return (
    <button
      type="button"
      disabled={!canSetFocalPoint}
      onClick={onFocalPointClick}
      className="group relative block w-full shrink-0 overflow-hidden rounded-lg border border-border bg-muted disabled:cursor-default"
    >
      {previewUrl ? (
        <>
          <img src={previewUrl} alt={alt} className={cn('w-full object-contain', className)} />
          {isImage && focalPoint && (
            <span
              aria-hidden
              className="pointer-events-none absolute size-5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_0_0_2px_rgba(0,0,0,0.4)]"
              style={{ left: `${focalPoint.x * 100}%`, top: `${focalPoint.y * 100}%` }}
            />
          )}
        </>
      ) : (
        // A video with no poster has no still to show; say which kind of file
        // it is rather than rendering a broken image.
        <div className="flex aspect-square w-full items-center justify-center text-muted-foreground">
          {isImage ? <ImagePlusIcon className="size-8" /> : <FilmIcon className="size-8" />}
        </div>
      )}
    </button>
  )
}
