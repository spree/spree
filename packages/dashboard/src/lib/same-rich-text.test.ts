import { sameRichText, shouldEmitRichTextChange } from '@spree/dashboard-ui'
import { describe, expect, it } from 'vitest'

describe('sameRichText', () => {
  it('treats empty markup as equal to an empty string', () => {
    expect(sameRichText('', '')).toBe(true)
    expect(sameRichText('', '<p></p>')).toBe(true)
    expect(sameRichText('', '<p><br></p>')).toBe(true)
    expect(sameRichText('<p></p>', '<p><br></p>')).toBe(true)
  })

  it('treats bare text as equal to the same text wrapped in a paragraph', () => {
    const plain = 'Höhenverstellbarer Standventilator mit 40cm Rotordurchmesser'
    expect(sameRichText(plain, `<p>${plain}</p>`)).toBe(true)
    expect(sameRichText(`<p>${plain}</p>`, `<p>${plain}</p><p></p>`)).toBe(true)
    expect(sameRichText(`<p>${plain}</p>`, `<p>${plain}</p><p><br></p><p></p>`)).toBe(true)
  })

  it('does not treat a real wording change as equal', () => {
    expect(sameRichText('<p>Standventilator</p>', '<p>Turmventilator</p>')).toBe(false)
    expect(sameRichText('Standventilator', '<p>Turmventilator</p>')).toBe(false)
  })

  it('does not treat a formatting-only change as equal', () => {
    expect(sameRichText('<p>Standventilator</p>', '<p><strong>Standventilator</strong></p>')).toBe(
      false,
    )
  })

  it('does not treat an image-only value as empty', () => {
    const imageOnly = '<p><img src="https://cdn.example/fan.jpg" alt="Fan"></p>'
    expect(sameRichText(imageOnly, '')).toBe(false)
    expect(sameRichText(imageOnly, '<p></p>')).toBe(false)
    expect(sameRichText(imageOnly, imageOnly)).toBe(true)
  })

  it('strips a long run of trailing empty paragraphs without hanging', () => {
    const empty = '<p></p>'.repeat(200)
    expect(sameRichText(`<p>Standventilator</p>${empty}`, '<p>Standventilator</p>')).toBe(true)
  })
})

describe('shouldEmitRichTextChange', () => {
  it('does not emit mount wrapping of empty or bare text', () => {
    expect(shouldEmitRichTextChange('<p></p>', '')).toBe(false)
    expect(shouldEmitRichTextChange('<p><br></p>', '')).toBe(false)
    expect(shouldEmitRichTextChange('<p>Hello</p>', 'Hello')).toBe(false)
  })

  it('emits a user-split empty paragraph that sameRichText would ignore', () => {
    expect(
      shouldEmitRichTextChange('<p>First paragraph</p><p></p>', '<p>First paragraph</p>'),
    ).toBe(true)
    expect(
      shouldEmitRichTextChange('<p>First paragraph</p><p><br></p>', '<p>First paragraph</p>'),
    ).toBe(true)
  })

  it('emits a wording or formatting change', () => {
    expect(shouldEmitRichTextChange('<p>Two</p>', '<p>One</p>')).toBe(true)
    expect(shouldEmitRichTextChange('<ul><li><p>One</p></li></ul>', '<p>One</p>')).toBe(true)
  })
})
