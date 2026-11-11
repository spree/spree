import type { DeveloperInspectorEntry } from '@spree/dashboard-core'

const REPOSITORY_URL = 'https://github.com/spree/spree'
// Matches Spree::Diagnostics::ISSUE_URL.
const ISSUE_FORM_URL = `${REPOSITORY_URL}/issues/new?template=bug_report.yml`
const DISCUSSION_URL = 'https://github.com/orgs/spree/discussions/new'
// Matches Spree::Diagnostics::MAX_ISSUE_URL_LENGTH: past this GitHub refuses
// the link, so the rest goes through the clipboard instead.
const MAX_URL_LENGTH = 6000
const TITLE_LENGTH = 80

export type FeedbackKind = 'bug' | 'idea' | 'other'

const DISCUSSION_CATEGORY: Record<Exclude<FeedbackKind, 'bug'>, string> = {
  idea: 'ideas',
  other: 'general',
}

export interface FeedbackInput {
  message: string
  /** Failed requests, from `failedRequestLines`. Bugs only. */
  logs?: string
  /** The diagnostics report's Markdown, when the admin can read it. */
  diagnostics?: string
  spreeVersion?: string
}

export interface FeedbackLink {
  /** The GitHub page to open. */
  url: string
  /** What the admin has to paste on GitHub, when the link can't carry it. */
  paste: string | null
}

/**
 * One line per failed request: method, path, status, error code and request
 * ID. Never the bodies or the query string, which carry customer data.
 */
export function failedRequestLines(entries: DeveloperInspectorEntry[]): string {
  return entries
    .map((entry) =>
      [
        entry.method,
        entry.path,
        entry.status ?? 'network error',
        entry.errorCode,
        entry.requestId && `request_id=${entry.requestId}`,
      ]
        .filter(Boolean)
        .join(' '),
    )
    .join('\n')
}

/** Everything as Markdown, for copying or pasting into GitHub. */
export function feedbackMarkdown(kind: FeedbackKind, input: FeedbackInput): string {
  if (kind !== 'bug') return discussionBody(input)
  return [
    input.message && `### What happened?\n\n${input.message}`,
    input.logs && `### Recent failed requests\n\n\`\`\`shell\n${input.logs}\n\`\`\``,
    input.diagnostics,
  ]
    .filter(Boolean)
    .join('\n\n')
}

/**
 * A bug opens the issue form with the message, failed requests and
 * diagnostics in their fields; an idea or anything else opens a new
 * discussion. When that is too long for a link, the largest part is left out
 * for the admin to paste.
 */
export function feedbackLink(kind: FeedbackKind, input: FeedbackInput): FeedbackLink {
  if (kind === 'bug') {
    return fit(
      ISSUE_FORM_URL,
      { description: input.message, logs: input.logs, environment: input.diagnostics },
      'environment',
      feedbackMarkdown(kind, input),
    )
  }

  const base = `${DISCUSSION_URL}?category=${DISCUSSION_CATEGORY[kind]}`
  const title = input.message.split('\n')[0].slice(0, TITLE_LENGTH)
  return fit(base, { title, body: discussionBody(input) }, 'body', discussionBody(input))
}

function discussionBody({ message, spreeVersion }: FeedbackInput): string {
  return spreeVersion ? `${message}\n\n---\nSpree ${spreeVersion}` : message
}

function fit(
  base: string,
  fields: Record<string, string | undefined>,
  pasteField: string,
  everything: string,
): FeedbackLink {
  const full = withFields(base, fields)
  if (full.length <= MAX_URL_LENGTH) return { url: full, paste: null }

  const { [pasteField]: left, ...rest } = fields
  const partial = withFields(base, rest)
  if (partial.length <= MAX_URL_LENGTH) return { url: partial, paste: left || null }

  return { url: base, paste: everything }
}

function withFields(url: string, fields: Record<string, string | undefined>): string {
  return Object.entries(fields)
    .filter(([, value]) => value)
    .reduce((acc, [key, value]) => `${acc}&${key}=${encodeURIComponent(value as string)}`, url)
}
