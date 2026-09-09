/**
 * Whether two rich-text strings are the same content after TipTap-style
 * normalization. The editor wraps bare text in `<p>` and emits empty
 * paragraphs (`<p></p>`, `<p><br></p>`) on mount — those must not count as
 * an edit against a stored plain-text or empty baseline.
 *
 * Implemented with linear scans so a long string of empty paragraphs cannot
 * trip a polynomial regular expression (CodeQL js/polynomial-redos).
 */
export function sameRichText(left: string, right: string): boolean {
  return canonicalizeRichText(left) === canonicalizeRichText(right)
}

function canonicalizeRichText(html: string): string {
  const withoutTrailingEmpty = stripTrailingEmptyParagraphs((html ?? '').trim())
  if (!visibleText(withoutTrailingEmpty) && !hasImage(withoutTrailingEmpty)) return ''
  if (!looksLikeHtml(withoutTrailingEmpty)) return `<p>${withoutTrailingEmpty}</p>`
  return withoutTrailingEmpty
}

function stripTrailingEmptyParagraphs(html: string): string {
  let end = html.length

  while (end > 0) {
    while (end > 0 && isAsciiWhitespace(html.charCodeAt(end - 1))) end -= 1
    if (!html.slice(0, end).toLowerCase().endsWith('</p>')) break

    const open = html.lastIndexOf('<p>', end - 4)
    if (open === -1 || open > end - 4) break

    const inner = html.slice(open + 3, end - 4).trim()
    if (inner === '' || isBreakOnly(inner) || isNbspOnly(inner)) {
      end = open
      continue
    }
    break
  }

  return html.slice(0, end).trim()
}

function isBreakOnly(inner: string): boolean {
  const lower = inner.toLowerCase()
  return lower === '<br>' || lower === '<br/>' || lower === '<br />'
}

function isNbspOnly(inner: string): boolean {
  return inner.replace(/&nbsp;/gi, '').trim() === ''
}

function isAsciiWhitespace(charCode: number): boolean {
  return charCode === 32 || charCode === 9 || charCode === 10 || charCode === 13
}

function looksLikeHtml(value: string): boolean {
  const start = value.search(/<\/?[a-z]/i)
  if (start === -1) return false
  return value.indexOf('>', start) !== -1
}

/** TipTap's image button can produce a paragraph that has no text. */
function hasImage(html: string): boolean {
  const lower = html.toLowerCase()
  let index = 0
  while (index < lower.length) {
    const open = lower.indexOf('<img', index)
    if (open === -1) return false
    const after = lower.charCodeAt(open + 4)
    if (
      Number.isNaN(after) ||
      after === 32 ||
      after === 9 ||
      after === 10 ||
      after === 13 ||
      after === 47 ||
      after === 62
    ) {
      return true
    }
    index = open + 4
  }
  return false
}

function visibleText(html: string): string {
  let text = ''
  let index = 0
  while (index < html.length) {
    const open = html.indexOf('<', index)
    if (open === -1) {
      text += html.slice(index)
      break
    }
    text += html.slice(index, open)
    const close = html.indexOf('>', open + 1)
    if (close === -1) {
      text += html.slice(open)
      break
    }
    text += ' '
    index = close + 1
  }
  return text
    .replace(/&nbsp;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}
