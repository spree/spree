// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ProductMediaParams = {
  id?: string
  /** A `signed_id` from `files.upload()`. */
  signed_id?: string
  /** Copies an asset from the media library. */
  source_media_id?: string
  alt?: string | null
  position?: number
  media_type?: 'image' | 'video' | 'external_video'
  external_video_url?: string | null
  poster_signed_id?: string
  focal_point_x?: number | null
  focal_point_y?: number | null
  /** Replaces the variants this media is linked to. An empty list clears them. */
  variant_ids?: string[]
}
