import { describe, it, expect } from 'vitest'
import { convertContent, resolveImports, extractFrontmatter, rewriteLinks } from '../scripts/convert.js'

// ---------------------------------------------------------------------------
// extractFrontmatter
// ---------------------------------------------------------------------------

describe('extractFrontmatter', () => {
  it('extracts YAML frontmatter', () => {
    const input = '---\ntitle: Hello\n---\nBody content'
    const { frontmatter, body } = extractFrontmatter(input)
    expect(frontmatter).toBe('---\ntitle: Hello\n---\n')
    expect(body).toBe('Body content')
  })

  it('returns null frontmatter when none present', () => {
    const input = 'Just body content'
    const { frontmatter, body } = extractFrontmatter(input)
    expect(frontmatter).toBeNull()
    expect(body).toBe('Just body content')
  })

  it('handles multi-field frontmatter', () => {
    const input = '---\ntitle: Test\ndescription: A test page\n---\nBody'
    const { frontmatter, body } = extractFrontmatter(input)
    expect(frontmatter).toContain('title: Test')
    expect(frontmatter).toContain('description: A test page')
    expect(body).toBe('Body')
  })
})

// ---------------------------------------------------------------------------
// convertContent — Callouts
// ---------------------------------------------------------------------------

describe('convertContent — callouts', () => {
  it('converts <Info> to blockquote', () => {
    const input = '<Info>\nThis is important.\n</Info>'
    expect(convertContent(input)).toContain('> **INFO:** This is important.')
  })

  it('converts <Warning> to blockquote', () => {
    const input = '<Warning>\nBe careful!\n</Warning>'
    expect(convertContent(input)).toContain('> **WARNING:** Be careful!')
  })

  it('converts <Tip> to blockquote', () => {
    const input = '<Tip>\nA helpful tip.\n</Tip>'
    expect(convertContent(input)).toContain('> **TIP:** A helpful tip.')
  })

  it('converts <Note> to blockquote', () => {
    const input = '<Note>\nTake note.\n</Note>'
    expect(convertContent(input)).toContain('> **NOTE:** Take note.')
  })

  it('handles multiline callout content', () => {
    const input = '<Info>\nLine one.\nLine two.\n</Info>'
    const result = convertContent(input)
    expect(result).toContain('> **INFO:** Line one.\n> Line two.')
  })

  it('is case-insensitive', () => {
    const input = '<info>\nLowercase tag.\n</info>'
    expect(convertContent(input)).toContain('> **INFO:** Lowercase tag.')
  })
})

// ---------------------------------------------------------------------------
// convertContent — Tabs
// ---------------------------------------------------------------------------

describe('convertContent — tabs', () => {
  it('converts tabs to labeled sections', () => {
    const input = `<Tabs>
  <Tab title="Ruby">
    Ruby content here.
  </Tab>
  <Tab title="JavaScript">
    JS content here.
  </Tab>
</Tabs>`
    const result = convertContent(input)
    expect(result).toContain('**Ruby:**')
    expect(result).toContain('Ruby content here.')
    expect(result).toContain('**JavaScript:**')
    expect(result).toContain('JS content here.')
  })
})

// ---------------------------------------------------------------------------
// convertContent — Steps
// ---------------------------------------------------------------------------

describe('convertContent — steps', () => {
  it('converts steps to numbered sections', () => {
    const input = `<Steps>
  <Step title="Install">
    Run npm install.
  </Step>
  <Step title="Configure">
    Edit config file.
  </Step>
</Steps>`
    const result = convertContent(input)
    expect(result).toContain('**Step 1: Install**')
    expect(result).toContain('Run npm install.')
    expect(result).toContain('**Step 2: Configure**')
    expect(result).toContain('Edit config file.')
  })
})

// ---------------------------------------------------------------------------
// convertContent — CodeGroup
// ---------------------------------------------------------------------------

describe('convertContent — CodeGroup', () => {
  it('strips CodeGroup tags, keeps code blocks', () => {
    const input = `<CodeGroup>

\`\`\`ruby
puts "hello"
\`\`\`

\`\`\`javascript
console.log("hello")
\`\`\`

</CodeGroup>`
    const result = convertContent(input)
    expect(result).not.toContain('CodeGroup')
    expect(result).toContain('puts "hello"')
    expect(result).toContain('console.log("hello")')
  })
})

// ---------------------------------------------------------------------------
// convertContent — Accordion
// ---------------------------------------------------------------------------

describe('convertContent — accordion', () => {
  it('converts Accordion to details/summary', () => {
    const input = `<Accordion title="Click to expand">
  Hidden content here.
</Accordion>`
    const result = convertContent(input)
    expect(result).toContain('<details>')
    expect(result).toContain('<summary>Click to expand</summary>')
    expect(result).toContain('Hidden content here.')
    expect(result).toContain('</details>')
  })

  it('strips AccordionGroup wrapper', () => {
    const input = `<AccordionGroup>
  <Accordion title="Item 1">Content 1</Accordion>
  <Accordion title="Item 2">Content 2</Accordion>
</AccordionGroup>`
    const result = convertContent(input)
    expect(result).not.toContain('AccordionGroup')
    expect(result).toContain('<summary>Item 1</summary>')
    expect(result).toContain('<summary>Item 2</summary>')
  })
})

// ---------------------------------------------------------------------------
// convertContent — Cards
// ---------------------------------------------------------------------------

describe('convertContent — cards', () => {
  it('converts Card with title and href to link', () => {
    const input = '<Card title="Products" href="/developer/core-concepts/products">Product docs</Card>'
    const result = convertContent(input)
    expect(result).toContain('- [Products](/developer/core-concepts/products) — Product docs')
  })

  it('converts Card with title only to bold', () => {
    const input = '<Card title="Products">Product docs</Card>'
    const result = convertContent(input)
    expect(result).toContain('- **Products** — Product docs')
  })

  it('strips CardGroup wrapper', () => {
    const input = '<CardGroup cols={2}>\n<Card title="A">a</Card>\n</CardGroup>'
    const result = convertContent(input)
    expect(result).not.toContain('CardGroup')
    expect(result).toContain('- **A** — a')
  })

  it('converts self-closing Card', () => {
    const input = '<Card title="Link" href="/page" />'
    const result = convertContent(input)
    expect(result).toContain('- [Link](/page)')
  })
})

// ---------------------------------------------------------------------------
// convertContent — Frame
// ---------------------------------------------------------------------------

describe('convertContent — Frame', () => {
  it('strips Frame wrapper, keeps content', () => {
    const input = '<Frame caption="Dashboard">\n  <img src="/images/dash.png" />\n</Frame>'
    const result = convertContent(input)
    expect(result).not.toContain('Frame')
    expect(result).toContain('<img src="/images/dash.png" />')
  })
})

// ---------------------------------------------------------------------------
// convertContent — ResponseField / ParamField
// ---------------------------------------------------------------------------

describe('convertContent — API field components', () => {
  it('converts ResponseField', () => {
    const input = '<ResponseField name="email" type="string">\n  The user email\n</ResponseField>'
    const result = convertContent(input)
    expect(result).toContain('- **`email`** (`string`) — The user email')
  })

  it('converts ParamField with body attr', () => {
    const input = '<ParamField body="name" type="string">\n  Product name\n</ParamField>'
    const result = convertContent(input)
    expect(result).toContain('- **`name`** (`string`) — Product name')
  })
})

// ---------------------------------------------------------------------------
// convertContent — misc components
// ---------------------------------------------------------------------------

describe('convertContent — misc', () => {
  it('removes Icon components', () => {
    const input = 'Before <Icon name="check" /> after'
    expect(convertContent(input)).toBe('Before  after')
  })

  it('converts CopyCommand to code block', () => {
    const input = '<CopyCommand command="npm install spree" />'
    const result = convertContent(input)
    expect(result).toContain('```bash\nnpm install spree\n```')
  })

  it('strips Columns wrapper', () => {
    const input = '<Columns>\nContent\n</Columns>'
    const result = convertContent(input)
    expect(result).not.toContain('Columns')
    expect(result).toContain('Content')
  })

  it('strips unknown paired components, keeps content', () => {
    const input = '<SectionHeading size="lg">\nMy Section\n</SectionHeading>'
    const result = convertContent(input)
    expect(result).not.toContain('SectionHeading')
    expect(result).toContain('My Section')
  })

  it('removes unknown self-closing components', () => {
    const input = 'Text <CustomWidget prop="val" /> more text'
    expect(convertContent(input)).toBe('Text  more text')
  })
})

// ---------------------------------------------------------------------------
// convertContent — code block protection
// ---------------------------------------------------------------------------

describe('convertContent — code block protection', () => {
  it('does not convert components inside code blocks', () => {
    const input = '```html\n<Info>This should stay</Info>\n```'
    const result = convertContent(input)
    expect(result).toContain('<Info>This should stay</Info>')
    expect(result).not.toContain('**INFO:**')
  })

  it('does not convert components inside inline code', () => {
    const input = 'Use `<Info>` for callouts'
    const result = convertContent(input)
    expect(result).toContain('`<Info>`')
  })

  it('collapses excessive blank lines', () => {
    const input = 'Line 1\n\n\n\n\n\nLine 2'
    const result = convertContent(input)
    expect(result).toBe('Line 1\n\n\nLine 2')
  })
})

// ---------------------------------------------------------------------------
// resolveImports
// ---------------------------------------------------------------------------

describe('resolveImports', () => {
  it('removes import lines', () => {
    const input = `import Foo from '/snippets/foo.mdx'\n\nBody content`
    const result = resolveImports(input)
    expect(result).not.toContain('import')
    expect(result).toContain('Body content')
  })

  it('replaces self-closing component with snippet content', () => {
    const input = `import MySnippet from '/snippets/my.mdx'\n\n<MySnippet />`
    const resolver = (path) => {
      if (path === '/snippets/my.mdx') return 'Inlined content'
      return ''
    }
    const result = resolveImports(input, resolver)
    expect(result).toContain('Inlined content')
    expect(result).not.toContain('MySnippet')
  })

  it('ignores non-snippet imports', () => {
    const input = `import { createClient } from '@spree/sdk'\n\nBody`
    const result = resolveImports(input)
    // Non-snippet imports are still removed (they're JS imports, not useful in MD)
    expect(result).toContain('Body')
  })

  it('handles multiple snippet imports', () => {
    const input = `import A from '/snippets/a.mdx'\nimport B from '/snippets/b.mdx'\n\n<A />\n<B />`
    const resolver = (path) => {
      if (path === '/snippets/a.mdx') return 'Content A'
      if (path === '/snippets/b.mdx') return 'Content B'
      return ''
    }
    const result = resolveImports(input, resolver)
    expect(result).toContain('Content A')
    expect(result).toContain('Content B')
  })
})

// ---------------------------------------------------------------------------
// rewriteLinks
// ---------------------------------------------------------------------------

describe('rewriteLinks', () => {
  it('converts absolute links to relative .md paths', () => {
    const input = '[Products](/developer/core-concepts/products)'
    const result = rewriteLinks(input, 'developer/core-concepts')
    expect(result).toBe('[Products](products.md)')
  })

  it('handles cross-directory links', () => {
    const input = '[Store API](/api-reference/store-api/introduction)'
    const result = rewriteLinks(input, 'developer/core-concepts')
    expect(result).toBe('[Store API](../../api-reference/store-api/introduction.md)')
  })

  it('preserves anchors', () => {
    const input = '[Translations](/developer/core-concepts/translations#resource-translations)'
    const result = rewriteLinks(input, 'developer/core-concepts')
    expect(result).toBe('[Translations](translations.md#resource-translations)')
  })

  it('handles links from nested directory to sibling', () => {
    const input = '[Admin](/developer/admin/navigation)'
    const result = rewriteLinks(input, 'developer/customization')
    expect(result).toBe('[Admin](../admin/navigation.md)')
  })

  it('does not rewrite external links', () => {
    const input = '[GitHub](https://github.com/spree/spree)'
    const result = rewriteLinks(input, 'developer/core-concepts')
    expect(result).toBe('[GitHub](https://github.com/spree/spree)')
  })

  it('does not rewrite links to non-doc paths', () => {
    const input = '[Home](/)'
    const result = rewriteLinks(input, 'developer/core-concepts')
    expect(result).toBe('[Home](/)')
  })

  it('handles links from root-level files', () => {
    const input = '[Products](/developer/core-concepts/products)'
    const result = rewriteLinks(input, 'developer')
    expect(result).toBe('[Products](core-concepts/products.md)')
  })

  it('handles integrations links', () => {
    const input = '[Stripe](/integrations/payments/stripe)'
    const result = rewriteLinks(input, 'developer/core-concepts')
    expect(result).toBe('[Stripe](../../integrations/payments/stripe.md)')
  })
})
