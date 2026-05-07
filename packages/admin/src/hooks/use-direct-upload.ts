import { useMutation } from '@tanstack/react-query'
import SparkMD5 from 'spark-md5'
import { adminClient } from '@/client'

function computeMD5Checksum(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunkSize = 2097152 // 2MB chunks
    const spark = new SparkMD5.ArrayBuffer()
    const reader = new FileReader()
    let currentChunk = 0
    const chunks = Math.ceil(file.size / chunkSize)

    reader.onload = (e) => {
      spark.append(e.target!.result as ArrayBuffer)
      currentChunk++

      if (currentChunk < chunks) {
        loadNext()
      } else {
        // Active Storage expects base64-encoded raw MD5 digest
        resolve(btoa(spark.end(true)))
      }
    }

    reader.onerror = () => reject(reader.error)

    function loadNext() {
      const start = currentChunk * chunkSize
      const end = Math.min(start + chunkSize, file.size)
      reader.readAsArrayBuffer(file.slice(start, end))
    }

    loadNext()
  })
}

interface UploadResult {
  signedId: string
  previewUrl: string
}

function sameOriginIfRailsDisk(url: string): string {
  try {
    const parsed = new URL(url)
    if (parsed.pathname.startsWith('/rails/active_storage/')) {
      return parsed.pathname + parsed.search
    }
    return url
  } catch {
    return url
  }
}

export function useDirectUpload() {
  return useMutation({
    mutationFn: async (file: File): Promise<UploadResult> => {
      const checksum = await computeMD5Checksum(file)

      // Step 1: Get presigned upload URL
      let response: {
        direct_upload: { url: string; headers: Record<string, string> }
        signed_id: string
      }
      try {
        response = await adminClient.directUploads.create({
          blob: {
            filename: file.name,
            byte_size: file.size,
            checksum,
            content_type: file.type || 'application/octet-stream',
          },
        })
      } catch (err) {
        throw new Error(`Presign failed: ${err instanceof Error ? err.message : err}`)
      }

      // Step 2: Upload file directly to storage.
      //
      // Active Storage's Disk service issues an absolute URL against the Rails
      // origin (e.g. http://localhost:3000/rails/active_storage/disk/...). In
      // dev the SPA runs on a different port and that controller doesn't speak
      // CORS, so the browser blocks the cross-origin PUT before any response
      // ("Failed to fetch"). When the URL points at a `/rails/active_storage/`
      // path we drop the host so the request goes through Vite's `/rails`
      // proxy and stays same-origin. Production S3 URLs are untouched.
      const uploadUrl = sameOriginIfRailsDisk(response.direct_upload.url)
      const uploadResponse = await fetch(uploadUrl, {
        method: 'PUT',
        headers: response.direct_upload.headers,
        body: file,
      })

      if (!uploadResponse.ok) {
        const text = await uploadResponse.text().catch(() => '')
        throw new Error(`Storage upload failed (${uploadResponse.status}): ${text}`)
      }

      return {
        signedId: response.signed_id,
        previewUrl: URL.createObjectURL(file),
      }
    },
  })
}
