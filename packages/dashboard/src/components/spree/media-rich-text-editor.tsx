import type { Media } from '@spree/admin-sdk'
import { adminClient, MediaPickerSheet, useDirectUpload } from '@spree/dashboard-core'
import { RichTextEditor, type RichTextEditorProps } from '@spree/dashboard-ui'
import { useCallback, useRef, useState } from 'react'
import { useCreateMediaLibraryFile } from '../../hooks/use-media-library'

/**
 * The rich text editor with image embedding wired to the store's media
 * library. Use this wherever a merchant writes a description; the bare
 * `RichTextEditor` from the UI package has no way to add a picture.
 *
 * Embeds are plain URLs pointing at a bounded, uncropped rendition of the
 * file. Nothing records which description uses which file, so deleting a file
 * from the library can leave a broken image behind — the library's delete flow
 * warns about that.
 */
export function MediaRichTextEditor(props: Omit<RichTextEditorProps, 'onRequestImage'>) {
  const [picking, setPicking] = useState(false)
  const directUpload = useDirectUpload()
  const createFile = useCreateMediaLibraryFile()

  // The editor asks for an image and waits; the sheet answers later, once the
  // merchant picks or backs out. Holding the promise's resolver here is what
  // bridges the two.
  const resolveRef = useRef<((media: { url: string; alt?: string | null } | null) => void) | null>(
    null,
  )

  const requestImage = useCallback(
    () =>
      new Promise<{ url: string; alt?: string | null } | null>((resolve) => {
        resolveRef.current = resolve
        setPicking(true)
      }),
    [],
  )

  // Answers the editor's pending request, once. Clearing the ref is what makes
  // the close that follows a successful pick a no-op rather than a cancel —
  // the sheet closes itself after confirming, so both paths run in order.
  function answer(media: { url: string; alt?: string | null } | null) {
    const resolve = resolveRef.current
    resolveRef.current = null
    resolve?.(media)
  }

  function handleOpenChange(open: boolean) {
    setPicking(open)
    // Closing without picking still has to answer, or the editor's await never
    // settles and the toolbar button looks dead on the next click.
    if (!open) answer(null)
  }

  return (
    <>
      <RichTextEditor {...props} onRequestImage={requestImage} />

      <MediaPickerSheet<Media>
        open={picking}
        onOpenChange={handleOpenChange}
        multiple={false}
        queryKey="rich-text-image"
        search={(query) =>
          adminClient.media.list({
            limit: 48,
            media_type_eq: 'image',
            ...(query ? { filename_cont: query } : {}),
          })
        }
        onUpload={async (file) => {
          const upload = await directUpload.mutateAsync(file)
          return createFile.mutateAsync({ signed_id: upload.signedId, alt: file.name })
        }}
        onConfirm={(picked) => {
          // The embed rendition is bounded but uncropped; the original is the
          // fallback for a file whose rendition isn't available.
          const media = picked[0]
          const url = media?.embed_url ?? media?.original_url
          answer(url ? { url, alt: media.alt } : null)
        }}
      />
    </>
  )
}
