import { useMutation } from '@tanstack/react-query'
import { getApiClient } from '../api-client'

interface UploadResult {
  signedId: string
  previewUrl: string
}

// Active Storage's Disk service issues an absolute URL against the Rails
// origin (e.g. http://localhost:3000/rails/active_storage/disk/...). In dev the
// SPA runs on a different port and that controller doesn't speak CORS, so the
// browser blocks the cross-origin PUT before any response ("Failed to fetch").
// When the URL points at a `/rails/active_storage/` path we drop the host so
// the request goes through Vite's `/rails` proxy and stays same-origin.
// Production storage URLs are untouched.
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

interface FileUploadOptions {
  /**
   * `private` for files only ever served through an authorized link
   * (documents, imports, digital products). Attaching a file never moves it
   * between storage services, so this has to be decided up front.
   */
  visibility?: 'public' | 'private'
}

export function useFileUpload(options: FileUploadOptions = {}) {
  return useMutation({
    mutationFn: async (file: File): Promise<UploadResult> => {
      const uploadFile = getApiClient().uploadFile
      if (!uploadFile) throw new Error('This panel cannot upload files.')

      const { signed_id } = await uploadFile(file, {
        visibility: options.visibility ?? 'public',
        resolveUploadUrl: sameOriginIfRailsDisk,
      })

      return { signedId: signed_id, previewUrl: URL.createObjectURL(file) }
    },
  })
}
