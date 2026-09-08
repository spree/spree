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
  const parsed = new DOMParser().parseFromString(html ?? '', 'text/html')
  const text = (parsed.body.textContent ?? '').replace(/\u00a0/g, ' ').trim()
  if (!text) return ''

  while (
    parsed.body.lastElementChild &&
    parsed.body.children.length > 1 &&
    !(parsed.body.lastElementChild.textContent ?? '').replace(/\u00a0/g, ' ').trim()
  ) {
    parsed.body.lastElementChild.remove()
  }

  if (parsed.body.children.length === 0) {
    return `<p>${parsed.body.innerHTML}</p>`
  }

  return parsed.body.innerHTML.trim()
}
