import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { ReleaseNotes } from './release-notes'

function render(markdown: string) {
  return renderToStaticMarkup(<ReleaseNotes markdown={markdown} />)
}

describe('release notes', () => {
  it('renders the markdown GitHub publishes, screenshots included', () => {
    const html = render(
      [
        '## Searchable Metafields',
        '<img width="1920" alt="shot" src="https://github.com/user-attachments/assets/shot.png" />',
        '* Fixed a thing by @someone in https://github.com/spree/spree/pull/1',
        '```curl\nGET /api/v3/store/products\n```',
      ].join('\n\n'),
    )

    expect(html).toContain('>Searchable Metafields</h3>')
    expect(html).toContain('src="https://github.com/user-attachments/assets/shot.png"')
    expect(html).toContain('<li>')
    expect(html).toContain('href="https://github.com/spree/spree/pull/1"')
    expect(html).toContain('<pre')
  })

  it('opens links in a new tab without handing the dashboard to the target', () => {
    const html = render('[docs](https://spreecommerce.org/docs)')

    expect(html).toContain('target="_blank"')
    expect(html).toContain('rel="noopener noreferrer"')
  })

  it('strips anything that could run script in the dashboard', () => {
    const html = render(
      [
        '<script>alert(1)</script>',
        '<img src="x" onerror="alert(2)" />',
        '[click](javascript:alert(3))',
        '<iframe src="https://evil.example"></iframe>',
      ].join('\n\n'),
    )

    expect(html).not.toContain('<script')
    expect(html).not.toContain('onerror')
    expect(html).not.toContain('javascript:')
    expect(html).not.toContain('<iframe')
  })
})
