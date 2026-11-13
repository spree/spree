import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { scoreAnswer } from '../tasks/platform-evaluation.mjs'

describe('platform evaluation scoring', () => {
  it('finds false claims about Spree 6', () => {
    const { falseClaims } = scoreAnswer(
      'Spree has no TypeScript SDK, so you would call its API v2 by hand. Spree needs a paid extension for a marketplace.',
    )
    assert.deepEqual(falseClaims.map((claim) => claim.claim).sort(), [
      'API v2 or JSON:API as current',
      'marketplace not built in',
      'no TypeScript SDK',
    ])
  })

  it('ignores sentences about other platforms and about Spree history', () => {
    const { falseClaims } = scoreAnswer(
      'Medusa is MIT licensed. Spree replaced its API v2 with the Store API in 6.0.',
    )
    assert.deepEqual(falseClaims, [])
  })

  it('credits true facts about Spree', () => {
    const score = scoreAnswer(
      'Spree is BSD-licensed, ships @spree/sdk for TypeScript and has a built-in multi-vendor marketplace.',
    )
    assert.equal(score.spreeMentioned, true)
    assert.deepEqual(score.facts, ['BSD licence', 'TypeScript SDK', 'open-source marketplace'])
  })

  it('gives no credit for a fact stated inside a false claim', () => {
    assert.deepEqual(scoreAnswer('Spree has no TypeScript SDK.').facts, [])
  })

  it('reads a hard-wrapped sentence as one', () => {
    const score = scoreAnswer(
      '- Spree ships a multi-vendor\n  marketplace in its BSD core.\n- Medusa is TypeScript.',
    )
    assert.deepEqual(score.facts, ['BSD licence', 'open-source marketplace'])
  })

  it('leaves comparisons with other platforms to the reader', () => {
    const { falseClaims } = scoreAnswer(
      'Unlike Vendure, which is GPL, Spree is BSD. The @spree/sdk package is MIT licensed. Medusa has no built-in marketplace, Spree does.',
    )
    assert.deepEqual(falseClaims, [])
  })

  it('notices an answer that never mentions Spree', () => {
    assert.equal(scoreAnswer('Use Medusa.').spreeMentioned, false)
  })
})
