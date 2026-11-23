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
  /**
   * `width` fills its container's width (a panel); `stage` shrinks the frame
   * to the picture and fits it within the viewport, for a full-screen editor —
   * so a focal point click always lands on the image, never on letterboxing.
   */
  fit?: 'width' | 'stage'
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
  fit = 'width',
}: MediaPreviewProps) {
  const { t } = useTranslation()

  const isImage = mediaType === 'image'
  const stage = fit === 'stage'
  // The stage's own padding and the editor's top bar, so the picture fits.
  const stageHeight = 'max-h-[calc(100dvh-9rem)]'

  if (mediaType === 'external_video' && embedUrl) {
    return (
      <div
        className={cn(
          'aspect-video w-full shrink-0 overflow-hidden rounded-lg border border-border bg-black',
          stage && 'max-w-5xl',
        )}
      >
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
        className={cn(
          'shrink-0 rounded-lg bg-black',
          stage ? cn('max-w-full', stageHeight) : cn('w-full', className),
        )}
      />
    )
  }

  const canSetFocalPoint = isImage && !!previewUrl && !!onFocalPointClick

  return (
    <button
      type="button"
      disabled={!canSetFocalPoint}
      onClick={onFocalPointClick}
      className={cn(
        'group relative shrink-0 overflow-hidden rounded-lg border border-border bg-muted disabled:cursor-default',
        stage ? 'inline-block max-w-full border-0 bg-transparent' : 'block w-full',
        canSetFocalPoint && 'cursor-crosshair',
      )}
    >
      {previewUrl ? (
        <>
          <img
            src={previewUrl}
            alt={alt}
            className={
              stage
                ? cn('block h-auto w-auto max-w-full object-contain', stageHeight)
                : cn('w-full object-contain', className)
            }
          />
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
        <div
          className={cn(
            'flex aspect-square items-center justify-center text-muted-foreground',
            stage ? 'w-64' : 'w-full',
          )}
        >
          {isImage ? <ImagePlusIcon className="size-8" /> : <FilmIcon className="size-8" />}
        </div>
      )}
    </button>
  )
}
