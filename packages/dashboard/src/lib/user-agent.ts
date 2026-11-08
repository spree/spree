// Order matters: Edge and Opera also announce Chrome, and every browser on iOS
// announces Safari, naming itself with its own token (CriOS, FxiOS, EdgiOS).
const BROWSERS: Array<[RegExp, Browser, string]> = [
  [/Edg\/|EdgA\/|EdgiOS\//, 'edge', 'Edge'],
  [/OPR\//, 'opera', 'Opera'],
  [/Firefox\/|FxiOS\//, 'firefox', 'Firefox'],
  [/Chrome\/|CriOS\//, 'chrome', 'Chrome'],
  [/Safari\//, 'safari', 'Safari'],
]

// iOS and Android before macOS and Linux, which their user agents also name.
const SYSTEMS: Array<[RegExp, string]> = [
  [/iPhone|iPad|iPod/, 'iOS'],
  [/Android/, 'Android'],
  [/Windows/, 'Windows'],
  [/Mac OS X/, 'macOS'],
  [/Linux/, 'Linux'],
]

export type Browser = 'chrome' | 'edge' | 'firefox' | 'opera' | 'safari'

/** `other` is a client that names no known browser, such as a script. */
export type DeviceKind = 'desktop' | 'mobile' | 'tablet' | 'other'

export interface UserAgentDescription {
  /** "Chrome on macOS", or the user agent itself for an unknown client. */
  label: string
  browser: Browser | null
  device: DeviceKind
}

/** A short reading of a user agent, for listing sessions. */
export function describeUserAgent(userAgent: string): UserAgentDescription {
  const match = BROWSERS.find(([pattern]) => pattern.test(userAgent))
  if (!match) return { label: userAgent, browser: null, device: 'other' }

  const [, browser, name] = match
  const system = SYSTEMS.find(([pattern]) => pattern.test(userAgent))?.[1]
  return {
    label: system ? `${name} on ${system}` : name,
    browser,
    device: deviceKind(userAgent),
  }
}

// Android tablets drop "Mobile" from their user agent; phones keep it.
function deviceKind(userAgent: string): DeviceKind {
  if (/iPad|Tablet/.test(userAgent) || (/Android/.test(userAgent) && !/Mobile/.test(userAgent))) {
    return 'tablet'
  }
  if (/iPhone|Mobile/.test(userAgent)) return 'mobile'
  return 'desktop'
}
