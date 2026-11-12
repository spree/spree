// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CreatePoDocumentParams = {
  filename: string
  content_type: string
  byte_size: number
  /** Base64-encoded MD5 digest of the file; the storage service checks the bytes against it. */
  checksum: string
}
