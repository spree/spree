// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type FileUploadCreateParams = {
  filename: string
  content_type: string
  byte_size?: number
  /** Base64-encoded MD5 digest of the file; the storage service checks the bytes against it. */
  checksum?: string
  /**
   * `public` (the default) for images, videos and CSV files anyone may fetch, `private` for any
   * type.
   */
  visibility?: 'public' | 'private'
  /** The bytes, for a multipart upload. */
  file?: string
}
