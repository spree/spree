import { describe, expect, it } from 'vitest'
import { describeUserAgent } from './user-agent'

describe('describeUserAgent', () => {
  it('names the browser and the system of a desktop', () => {
    expect(
      describeUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      ),
    ).toEqual({ label: 'Chrome on macOS', browser: 'chrome', device: 'desktop' })
  })

  it('tells Edge apart from the Chrome it also announces', () => {
    expect(
      describeUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
      ),
    ).toMatchObject({ label: 'Edge on Windows', browser: 'edge' })
  })

  it('reads an iPhone as an iOS phone rather than macOS', () => {
    expect(
      describeUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
      ),
    ).toEqual({ label: 'Safari on iOS', browser: 'safari', device: 'mobile' })
  })

  it('reads Chrome and Edge on mobile by their own tokens', () => {
    expect(
      describeUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/130.0.6723.90 Mobile/15E148 Safari/604.1',
      ),
    ).toEqual({ label: 'Chrome on iOS', browser: 'chrome', device: 'mobile' })
    expect(
      describeUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36 EdgA/130.0.0.0',
      ),
    ).toEqual({ label: 'Edge on Android', browser: 'edge', device: 'mobile' })
  })

  it('reads an Android device without "Mobile" as a tablet', () => {
    expect(
      describeUserAgent(
        'Mozilla/5.0 (Linux; Android 14; SM-X710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      ),
    ).toEqual({ label: 'Chrome on Android', browser: 'chrome', device: 'tablet' })
  })

  it('falls back to the raw value for an unknown client', () => {
    expect(describeUserAgent('curl/8.7.1')).toEqual({
      label: 'curl/8.7.1',
      browser: null,
      device: 'other',
    })
  })
})
