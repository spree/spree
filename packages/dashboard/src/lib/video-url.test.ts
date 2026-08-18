import { describe, expect, it } from 'vitest'
import { isSupportedVideoUrl, parseVideoUrl } from './video-url'

describe('parseVideoUrl', () => {
  it.each([
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=42',
    'https://youtu.be/dQw4w9WgXcQ',
    'https://www.youtube.com/embed/dQw4w9WgXcQ',
    'https://www.youtube.com/shorts/dQw4w9WgXcQ',
  ])('reads the YouTube link %s', (url) => {
    expect(parseVideoUrl(url)).toEqual({
      provider: 'youtube',
      videoId: 'dQw4w9WgXcQ',
      embedUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
      thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    })
  })

  it.each([
    'https://vimeo.com/123456789',
    'https://player.vimeo.com/video/123456789',
    'https://vimeo.com/channels/staffpicks/123456789',
  ])('reads the Vimeo link %s', (url) => {
    expect(parseVideoUrl(url)).toEqual({
      provider: 'vimeo',
      videoId: '123456789',
      embedUrl: 'https://player.vimeo.com/video/123456789',
      thumbnailUrl: null,
    })
  })

  // Mirrors the Ruby spec of the same name — the two parsers must agree, or
  // the dialog accepts a link the server rejects.
  it('accepts a trailing slash, as an address-bar copy carries', () => {
    expect(parseVideoUrl('https://youtu.be/dQw4w9WgXcQ/')?.videoId).toBe('dQw4w9WgXcQ')
    expect(parseVideoUrl('https://vimeo.com/123456789/')?.videoId).toBe('123456789')
  })

  it('ignores surrounding whitespace', () => {
    expect(parseVideoUrl('  https://vimeo.com/123456789  ')?.videoId).toBe('123456789')
  })

  it.each([
    // Not videos: a channel, a handle, an arbitrary nested path, or a short
    // link with anything after the id.
    'https://www.youtube.com/c/dQw4w9WgXcQ',
    'https://www.youtube.com/not-a-video/ABCDEFGHIJK',
    'https://youtu.be/dQw4w9WgXcQ/extra',
    'https://example.com/video.mp4',
    'https://www.youtube.com/watch?v=short',
    'https://vimeo.com/not-a-number',
    'javascript:alert(1)',
    'not a url',
    '',
    null,
    undefined,
  ])('returns null for %s', (url) => {
    expect(parseVideoUrl(url)).toBeNull()
  })
})

describe('isSupportedVideoUrl', () => {
  it('accepts a link Spree can embed', () => {
    expect(isSupportedVideoUrl('https://vimeo.com/123456789')).toBe(true)
  })

  it('rejects anything else', () => {
    expect(isSupportedVideoUrl('https://example.com/clip.mp4')).toBe(false)
  })
})
