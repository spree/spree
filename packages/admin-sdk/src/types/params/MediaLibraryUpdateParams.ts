// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type MediaLibraryUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
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
  focal_point_x?: number | null
  focal_point_y?: number | null
  /**
   * The file itself, sent as multipart form data. JSON clients upload first and send `signed_id`.
   */
  attachment?: string
  /**
   * Fetch an image from this URL, in the background. Images only: an external video uses
   * `external_video_url`.
   */
  url?: string
  /** A `signed_id` from `files.upload()` for the media file itself. */
  signed_id?: string
  /**
   * Place a file that is already in the library. The new row shares the source file rather than
   * copying it, and takes its own alt, position and variant links from here.
   */
  source_media_id?: string
  /** Variants to link this product-level media to. Variants of other products are dropped. */
  variant_ids?: string[]
}
