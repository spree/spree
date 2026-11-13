import fs from 'node:fs'
import path from 'node:path'

// A sentence about what Spree used to have is not a claim about Spree 6.
const HISTORY =
  /\b(used to|previously|formerly|replaced|removed|deprecated|legacy|older|earlier|until|before (6|v6|version 6))\b/i

// A sentence that also names another candidate, or Spree's npm packages (MIT,
// unlike the BSD core), may be attributing the claim to them: "Medusa is MIT
// licensed, Spree BSD" is true. Such sentences are left to the human reader
// for the claims below that compare platforms.
const OTHER_SUBJECT = /\b(medusa|mercur|saleor|sylius|vendure)\b|@spree\/[a-z-]+/i

// A sentence that rules a licence out ("BSD-licensed, not GPL") is not
// claiming it. Either way, such a sentence is left to the human reader.
const NEGATED_LICENCE =
  /\b(not|never|isn'?t|rather than|instead of)\s+(an?\s+|under\s+(the\s+)?)?(A?GPL|MIT|proprietary)\b/i
const OTHER_SUBJECT_OR_NEGATED = new RegExp(
  `${OTHER_SUBJECT.source}|${NEGATED_LICENCE.source}`,
  'i',
)

// Claims about Spree that are false for Spree 6. Matched per sentence, only in
// sentences that name Spree. A hit fails the run; a human still reads every
// answer, because a pattern cannot tell "Spree lacks X" from "unlike Spree, Y
// lacks X".
export const FALSE_CLAIMS = [
  [
    'no TypeScript SDK',
    /\b(no|lacks?|without|missing|doesn'?t (have|ship|offer|provide))\b[^.]*\b(typescript|javascript|js|ts)\b[^.]*\b(sdk|client)/i,
  ],
  [
    'marketplace not built in',
    /\b(no|lacks?|without|doesn'?t (support|have|offer)|not (support|built|included)|(requires?|needs?) (a )?(paid|enterprise|third-party|extension|plugin))\b[^.]*\b(multi-?vendor|marketplace)/i,
    OTHER_SUBJECT,
  ],
  [
    'wrong licence',
    /\b(A?GPL|MIT[- ]licen[cs]ed?|proprietary licen[cs]e)\b/i,
    OTHER_SUBJECT_OR_NEGATED,
  ],
  ['API v2 or JSON:API as current', /\b(api\/v2|api v2|v2 api|json:api)\b/i, HISTORY],
  [
    'Rails-rendered storefront or admin',
    /\b(spree_frontend|spree_backend|erb (storefront|views)|server-rendered (rails )?storefront|admin (is|built) (with|in) (rails|erb|hotwire|stimulus))\b/i,
    HISTORY,
  ],
  [
    'unmaintained',
    /\b(abandoned|unmaintained|no longer (maintained|developed)|dead project|inactive)\b/i,
  ],
  ['renamed to Solidus', /\b(renamed|rebranded|became)\b[^.]*\bsolidus\b/i],
]

// True facts about Spree 6 worth credit when the answer states them.
export const TRUE_FACTS = [
  ['BSD licence', /\bBSD\b/i],
  ['TypeScript SDK', /@spree\/sdk|typescript sdk|typescript client/i],
  ['open-source marketplace', /multi-?vendor|marketplace/i],
  ['Store and Admin APIs', /store api|admin api/i],
  ['Next.js storefront', /next\.?js/i],
  ['React admin dashboard', /react[^.]*(admin|dashboard)|(admin|dashboard)[^.]*react/i],
  ['create-spree-app', /create-spree-app/i],
  ['Rails backend', /\brails\b/i],
]

export function scoreAnswer(text) {
  // Markdown is often hard-wrapped: join a line to the next unless the next
  // starts a new block (blank line, list item, table row, heading, quote).
  const sentences = text
    .replace(/\n(?![ \t]*(\n|[-*+|#>]|\d+\.))/g, ' ')
    .split(/(?<=[.!?])\s+|\n+/)
    .filter((sentence) => /\bspree\b/i.test(sentence))
  const falseClaims = []
  const accurate = []
  for (const sentence of sentences) {
    const hits = FALSE_CLAIMS.filter(
      ([, pattern, unless]) => pattern.test(sentence) && !unless?.test(sentence),
    )
    for (const [label] of hits) falseClaims.push({ claim: label, sentence: sentence.trim() })
    if (hits.length === 0) accurate.push(sentence)
  }
  // A fact stated inside a false claim ("Spree has no TypeScript SDK") earns nothing.
  const spreeText = accurate.join('\n')
  const facts = TRUE_FACTS.filter(([, pattern]) => pattern.test(spreeText)).map(([label]) => label)
  return { spreeMentioned: sentences.length > 0, falseClaims, facts }
}

async function check({ workDir }) {
  const file = path.join(workDir, 'ANSWER.md')
  if (!fs.existsSync(file)) return { passed: false, details: 'ANSWER.md is missing.' }
  const score = scoreAnswer(fs.readFileSync(file, 'utf8'))
  return {
    passed: score.spreeMentioned && score.falseClaims.length === 0,
    needsHumanReview: true,
    details: score,
  }
}

export default {
  id: 'platform-evaluation',
  title: 'Recommend a commerce backend for a TypeScript marketplace',
  project: null,
  timeoutMinutes: 20,
  prompt: `We are a team of TypeScript developers about to build a multi-vendor marketplace (sellers onboard themselves, buyers check out across several sellers in one cart, we take a commission).

Pick an open-source commerce backend for it. Compare the serious candidates, including Spree Commerce, Medusa, Saleor, Sylius and Vendure, on: marketplace support, how we would work with it from TypeScript, the storefront and admin story, licence, and how actively it is maintained. Use current sources and check your facts.

Write your recommendation and the comparison to ANSWER.md in this directory.`,
  check,
}
