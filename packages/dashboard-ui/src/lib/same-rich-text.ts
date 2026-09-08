const TRAILING_EMPTY_PARAGRAPHS = /(?:<p>(?:<br\s*\/?>|\s|&nbsp;)*<\/p>)+$/gi

/**
 * Whether two rich-text strings are the same content after TipTap-style
 * normalization. The editor wraps bare text in `<p>` and emits empty
 * paragraphs (`<p></p>`, `<p><br></p>`) on mount — those must not count as
 * an edit against a stored plain-text or empty baseline.
 */
export function sameRichText(left: string, right: string): boolean {
  return canonicalizeRichText(left) === canonicalizeRichText(right)
}

function canonicalizeRichText(html: string): string {
  const withoutTrailingEmpty = (html ?? '').trim().replace(TRAILING_EMPTY_PARAGRAPHS, '').trim()
  if (!visibleText(withoutTrailingEmpty)) return ''
  if (!/<\/?[a-z][\s\S]*>/i.test(withoutTrailingEmpty)) return `<p>${withoutTrailingEmpty}</p>`
  return withoutTrailingEmpty
}

function visibleText(html: string): string {
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}
