// Single-use tokens travel in URLs: `?token=` on password reset, email
// confirmation and invitation links (and the invitation API calls), and the
// path of the password reset API call (`/auth/password_resets/<token>`).
// Nothing sent to Sentry — URLs, paths, error and log messages — may carry them.
const TOKEN_PATTERNS = [/([?&]token=)[^&#\s"']+/g, /(\/password_resets\/)[^/?#\s"']+/g]

export function redactTokens(value: string) {
  return TOKEN_PATTERNS.reduce((text, pattern) => text.replace(pattern, '$1redacted'), value)
}
