// Mirror of Spree::ExternalVideo on the server. The server is the authority —
// this exists so the merchant learns a link is unusable while typing it, not
// after a failed save.

const YOUTUBE_HOSTS = [
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtu.be',
  'www.youtu.be',
]
const VIMEO_HOSTS = ['vimeo.com', 'www.vimeo.com', 'player.vimeo.com']

const YOUTUBE_ID = /^[\w-]{11}$/
const VIMEO_ID = /^\d+$/

export interface ParsedVideoUrl {
  provider: 'youtube' | 'vimeo'
  videoId: string
  embedUrl: string
  thumbnailUrl: string | null
}

export function parseVideoUrl(input: string | null | undefined): ParsedVideoUrl | null {
  if (!input?.trim()) return null

  let url: URL
  try {
    url = new URL(input.trim())
  } catch {
    return null
  }

  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null

  const host = url.hostname.toLowerCase()
  const segments = url.pathname.split('/').filter(Boolean)

  if (YOUTUBE_HOSTS.includes(host)) {
    const videoId = host.includes('youtu.be')
      ? segments[0]
      : url.pathname === '/watch'
        ? (url.searchParams.get('v') ?? '')
        : (segments.at(-1) ?? '')

    if (!YOUTUBE_ID.test(videoId)) return null

    return {
      provider: 'youtube',
      videoId,
      embedUrl: `https://www.youtube.com/embed/${videoId}`,
      thumbnailUrl: `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
    }
  }

  if (VIMEO_HOSTS.includes(host)) {
    const videoId = segments.at(-1) ?? ''
    if (!VIMEO_ID.test(videoId)) return null

    // Vimeo thumbnails need an API call, so there is no provider still here.
    return {
      provider: 'vimeo',
      videoId,
      embedUrl: `https://player.vimeo.com/video/${videoId}`,
      thumbnailUrl: null,
    }
  }

  return null
}

export function isSupportedVideoUrl(url: string | null | undefined): boolean {
  return parseVideoUrl(url) !== null
}
