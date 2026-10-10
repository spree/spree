import SparkMD5 from 'spark-md5'

/** What `POST /files` accepts as JSON, for a presigned upload. */
export interface FileUploadCreateParams {
  filename: string
  content_type: string
  byte_size: number
  /** Base64-encoded MD5 digest of the file; the storage service checks the bytes against it. */
  checksum: string
  /** `public` (the default) for images and videos customers see, `private` for anything else. */
  visibility?: 'public' | 'private'
}

/** The parts of the `POST /files` response the upload helper reads. */
export interface FileUploadResponse {
  signed_id: string
  upload: { method: string; url: string; headers: Record<string, string> } | null
}

export interface UploadFileOptions {
  visibility?: 'public' | 'private'
  /** Defaults to the file's own name, when it has one. */
  filename?: string
  /** Defaults to the file's own type. */
  contentType?: string
  /**
   * `presigned` (the default) sends the bytes straight to storage, for files
   * of any size. `multipart` sends them in the request itself, which needs no
   * checksum but is limited to 10 MB by default.
   */
  method?: 'presigned' | 'multipart'
  /** Rewrites the storage URL before the bytes are sent, e.g. to keep a dev proxy same-origin. */
  resolveUploadUrl?: (url: string) => string
  /** Used for the storage request. Defaults to the global `fetch`. */
  fetch?: typeof fetch
}

const MD5_CHUNK_SIZE = 2 * 1024 * 1024

/** Base64-encoded MD5 digest of a file, read in chunks so large files stay out of memory. */
export async function computeChecksum(file: Blob): Promise<string> {
  const spark = new SparkMD5.ArrayBuffer()
  for (let start = 0; start < file.size; start += MD5_CHUNK_SIZE) {
    spark.append(await file.slice(start, start + MD5_CHUNK_SIZE).arrayBuffer())
  }
  return btoa(spark.end(true))
}

/**
 * Uploads a file through `POST /files` and resolves to the response, whose
 * `signed_id` is what the endpoint that uses the file takes.
 *
 * @param create - the client's `files.create`
 */
export async function uploadFile<T extends FileUploadResponse>(
  create: (body: FileUploadCreateParams | FormData) => Promise<T>,
  file: Blob,
  options: UploadFileOptions = {},
): Promise<T> {
  const filename = options.filename ?? (file as Blob & { name?: string }).name ?? 'file'
  const contentType = options.contentType || file.type || 'application/octet-stream'
  const visibility = options.visibility ?? 'public'

  if (options.method === 'multipart') {
    const form = new FormData()
    form.append('file', file, filename)
    form.append('filename', filename)
    form.append('content_type', contentType)
    form.append('visibility', visibility)
    return create(form)
  }

  const response = await create({
    filename,
    content_type: contentType,
    byte_size: file.size,
    checksum: await computeChecksum(file),
    visibility,
  })
  if (!response.upload) return response

  const url = options.resolveUploadUrl
    ? options.resolveUploadUrl(response.upload.url)
    : response.upload.url
  const fetchFn = options.fetch ?? fetch.bind(globalThis)
  const stored = await fetchFn(url, {
    method: response.upload.method,
    headers: response.upload.headers,
    body: file,
  })
  if (!stored.ok) {
    const text = await stored.text().catch(() => '')
    throw new Error(`Storage upload failed (${stored.status}): ${text}`)
  }

  return response
}
