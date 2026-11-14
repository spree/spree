// Single-use tokens travel in URLs: `?token=` on password reset, email
// confirmation and invitation links (and the invitation API calls), and the
// path of the password reset API call (`/auth/password_resets/<token>`).
// Nothing sent to Sentry — URLs, paths, error and log messages — may carry them,
// including percent-encoded inside another URL (`?redirect=%2F…%3Ftoken%3D…`).
const TOKEN_PATTERNS = [
  /((?:[?&#]|%3F|%26|%23)token(?:=|%3D))(?:(?!%26|%23)[^&#\s"'])+/gi,
  /((?:\/|%2F)password_resets(?:\/|%2F))(?:(?!%2F|%3F|%23)[^/?#\s"'])+/gi,
]

export function redactTokens(value: string) {
  return TOKEN_PATTERNS.reduce((text, pattern) => text.replace(pattern, '$1redacted'), value)
}
