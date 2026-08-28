import {
  FileArchiveIcon,
  FileAudioIcon,
  FileCodeIcon,
  FileIcon,
  FileImageIcon,
  FileSpreadsheetIcon,
  FileTextIcon,
  FileVideoIcon,
} from 'lucide-react'
import type { ComponentType } from 'react'

type IconComponent = ComponentType<{ className?: string }>

// Matched on the MIME type where it is specific enough, then on the extension —
// servers routinely hand back `application/octet-stream` for anything they do
// not recognise, which would otherwise flatten every row to a blank page icon.
const BY_SUBTYPE: Array<[RegExp, IconComponent]> = [
  [/^image\//, FileImageIcon],
  [/^audio\//, FileAudioIcon],
  [/^video\//, FileVideoIcon],
  [/(zip|compressed|tar|gzip|rar|7z)/, FileArchiveIcon],
  [/(spreadsheet|excel|csv)/, FileSpreadsheetIcon],
  [/(json|xml|javascript|typescript|html|x-ruby|x-python|x-sh)/, FileCodeIcon],
  [/(pdf|word|document|text|rtf|epub)/, FileTextIcon],
]

const BY_EXTENSION: Array<[RegExp, IconComponent]> = [
  [/\.(png|jpe?g|gif|webp|svg|avif|heic|tiff?)$/i, FileImageIcon],
  [/\.(mp3|wav|flac|aac|ogg|m4a|aiff?)$/i, FileAudioIcon],
  [/\.(mp4|mov|avi|mkv|webm|m4v)$/i, FileVideoIcon],
  [/\.(zip|rar|7z|tar|gz|bz2|dmg|iso)$/i, FileArchiveIcon],
  [/\.(csv|tsv|xlsx?|numbers|ods)$/i, FileSpreadsheetIcon],
  [/\.(json|xml|ya?ml|js|ts|tsx|rb|py|sh|css|html?)$/i, FileCodeIcon],
  [/\.(pdf|docx?|txt|rtf|md|epub|pages)$/i, FileTextIcon],
]

/**
 * Picks the icon for a downloadable file. Falls back to a plain page rather
 * than guessing, so an unknown type reads as "a file" instead of the wrong one.
 */
export function fileTypeIcon(filename?: string | null, contentType?: string | null): IconComponent {
  const type = contentType?.toLowerCase() ?? ''
  for (const [pattern, icon] of BY_SUBTYPE) {
    if (pattern.test(type)) return icon
  }

  const name = filename ?? ''
  for (const [pattern, icon] of BY_EXTENSION) {
    if (pattern.test(name)) return icon
  }

  return FileIcon
}

/** Convenience wrapper for the common `<FileTypeIcon .../>` call site. */
export function FileTypeIcon({
  filename,
  contentType,
  className,
}: {
  filename?: string | null
  contentType?: string | null
  className?: string
}) {
  const Icon = fileTypeIcon(filename, contentType)
  return <Icon className={className} />
}
