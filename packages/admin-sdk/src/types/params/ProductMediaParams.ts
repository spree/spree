// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type ProductMediaParams = {
  id?: string
  /** A `signed_id` from `files.upload()`. */
  signed_id?: string
  /** Copies an asset from the media library. */
  source_media_id?: string
  alt?: string | null
  position?: number
  /**
   * Defaults to `image`. `video` needs a `signed_id`; `external_video` needs an
   * `external_video_url`.
   */
  media_type?: 'image' | 'video' | 'external_video'
  /** YouTube or Vimeo link. Required when `media_type` is `external_video`. */
  external_video_url?: string | null
  /** A `signed_id` from `files.upload()` for a video's poster frame. */
  poster_signed_id?: string
  /** Where the image is anchored when cropped, from 0 to 1. */
  focal_point_x?: number | null
  /** Where the image is anchored when cropped, from 0 to 1. */
  focal_point_y?: number | null
  /** Replaces the variants this media is linked to. An empty list clears them. */
  variant_ids?: string[]
}
