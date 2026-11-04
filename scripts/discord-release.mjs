// Posts a GitHub release of spree/spree to Discord as a digest embed: the
// intro paragraph, the upgrade command, feature titles, a one-line summary of
// each other change, upgrade notes and contributors, with a link to the full
// notes. Run by
// discord-release.yml:
//
//   node scripts/discord-release.mjs <tag>             post to $DISCORD_WEBHOOK_URL
//   node scripts/discord-release.mjs <tag> --dry-run   print the payload only
//
// Only `v*` tags are posted; @spree/cli and create-spree-app releases are not.
// Reads the release from the GitHub API with $GITHUB_TOKEN (optional locally),
// or from the JSON file at $RELEASE_FILE.
//
// Contributors listed in .github/discord-contributors.json (GitHub login →
// Discord user id) are pinged in the message; Discord can't notify by name.

const REPO = process.env.GITHUB_REPOSITORY || 'spree/spree'
const COLOR = 0x2ecc71
const MAX_TITLES = 8
const MAX_SUMMARY = 120
// Discord rejects an embed past 6000 characters or 25 fields.
const MAX_EMBED = 6000
const MAX_FIELDS = 25

// Sections that never make it into the embed.
const SKIP = /package versions|contributors|installation|feedback/i

const [tag, flag] = process.argv.slice(2)
const dryRun = flag === '--dry-run'

if (!tag || !/^v\d/.test(tag)) {
  console.log(`Skipping "${tag}": only v* tags are posted.`)
  process.exit(0)
}

const release = await fetchRelease(tag)
if (release.draft || release.prerelease) {
  console.log(`Skipping ${tag}: draft or prerelease.`)
  process.exit(0)
}

const payload = { ...thanks(contributorsOf(release), await discordIds()), embeds: [buildEmbed(release)] }

if (dryRun) {
  console.log(JSON.stringify(payload, null, 2))
} else {
  await post(payload)
  console.log(`Posted ${tag} to Discord.`)
}

async function fetchRelease(tag) {
  // Lets you try a payload from a saved `gh api repos/spree/spree/releases/tags/<tag>`.
  if (process.env.RELEASE_FILE) {
    const { readFileSync } = await import('node:fs')
    return JSON.parse(readFileSync(process.env.RELEASE_FILE, 'utf8'))
  }
  const headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'spree-discord-release' }
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`
  const res = await fetch(`https://api.github.com/repos/${REPO}/releases/tags/${encodeURIComponent(tag)}`, { headers })
  if (!res.ok) throw new Error(`GitHub API ${res.status} for release ${tag}`)
  return res.json()
}

async function post(payload) {
  const url = process.env.DISCORD_WEBHOOK_URL
  if (!url) throw new Error('DISCORD_WEBHOOK_URL is not set')
  for (let attempt = 0; attempt < 2; attempt++) {
    const res = await fetch(`${url}?wait=true`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
    if (res.ok) return
    if (res.status === 429 && attempt === 0) {
      const { retry_after = 1 } = await res.json().catch(() => ({}))
      await new Promise((r) => setTimeout(r, retry_after * 1000))
      continue
    }
    throw new Error(`Discord ${res.status}: ${await res.text()}`)
  }
}

export function buildEmbed(release) {
  // Notes are sometimes indented as a whole block; dedent every line.
  const lines = (release.body || '').replace(/\r/g, '').split('\n').map((l) => l.trim())
  const sections = parseSections(lines)

  const titled = []
  const upgrades = []
  const highlights = []

  for (const { heading, body } of sections) {
    if (SKIP.test(heading)) continue
    const bullets = body.filter((l) => /^[-*] /.test(l)).map((l) => l.slice(2))
    if (!bullets.length) continue

    if (/upgrad/i.test(heading)) {
      upgrades.push({ name: clip(heading, 256), value: clip(bullets.map((b) => `• ${b}`).join('\n'), 1024) })
      continue
    }

    const titles = bullets.map((b) => b.match(/^\*\*(.+?)\.?\*\*/)?.[1]).filter(Boolean)
    if (titles.length) {
      const name = clip(`${heading} (${bullets.length})`, 256)
      titled.push({ name, value: list(titles), brief: name })
    } else if (/^\p{Extended_Pictographic}/u.test(heading)) {
      const name = clip(`${heading} (${bullets.length})`, 256)
      titled.push({ name, value: list(bullets.map(summary)), brief: name })
    } else {
      // Major releases describe areas under plain headings; name the areas.
      highlights.push(heading)
    }
  }

  if (highlights.length) titled.unshift({ name: '✨ Highlights', value: list(highlights), brief: '✨ Highlights' })

  // Upgrade notes and contributors always fit; the other sections fill what is left.
  const required = upgrades.slice(0, 3)
  const contributors = contributorsOf(release)
  if (contributors.length) {
    required.push({
      name: `🙌 Thanks to ${contributors.length} community contributor${contributors.length > 1 ? 's' : ''}`,
      value: joinFitting(contributors.map((c) => `[@${c}](https://github.com/${c})`), 1000, ', '),
    })
  }

  const description = [
    clip(intro(lines), 600),
    /npx spree upgrade/.test(release.body || '') && '```\nnpx spree upgrade\n```',
    `**[Full release notes →](${release.html_url})**`,
  ].filter(Boolean).join('\n\n')

  const embed = {
    author: { name: REPO, url: `https://github.com/${REPO}` },
    title: clip(title(release, lines), 256),
    url: release.html_url,
    description,
    color: COLOR,
    fields: [],
    timestamp: release.published_at,
  }

  // Space is held back so a section that doesn't fit is still named in one line.
  const reserve = 300
  let budget = MAX_EMBED - size(embed) - required.reduce((n, f) => n + size(f), 0) - reserve
  const left = []
  for (const { brief, ...field } of titled) {
    if (embed.fields.length < MAX_FIELDS - required.length - 1 && size(field) <= budget) {
      embed.fields.push(field)
      budget -= size(field)
    } else {
      left.push(brief)
    }
  }
  embed.fields.push(...required)
  const room = MAX_EMBED - size(embed) - embed.fields.reduce((n, f) => n + size(f), 0) - 20
  if (left.length && room > 20) {
    embed.fields.splice(embed.fields.length - required.length, 0, { name: 'Also in this release', value: joinFitting(left, Math.min(reserve - 25, room)) })
  }

  const image = (release.body || '').match(/<img[^>]+src="([^"]+)"/)?.[1]
  if (image) embed.image = { url: image }

  return embed
}

function parseSections(lines) {
  const sections = []
  let current = null
  let inFence = false
  for (const line of lines) {
    if (line.startsWith('```')) inFence = !inFence
    if (inFence || line.startsWith('```')) continue
    const m = line.match(/^#{1,3} (.+)/)
    if (m) {
      current = { heading: m[1].trim(), body: [] }
      sections.push(current)
    } else if (current) {
      current.body.push(line)
    }
  }
  return sections
}

// The first prose paragraph: not a heading, image, fence, rule or table.
function intro(lines) {
  const paragraph = []
  let inFence = false
  for (const line of lines) {
    if (line.startsWith('```')) inFence = !inFence
    const prose = !inFence && line && !/^(#|<|```|---|\||[-*] )/.test(line)
    if (prose) paragraph.push(line)
    else if (paragraph.length) break
  }
  return paragraph.join(' ')
}

function title(release, lines) {
  if (release.name && release.name !== release.tag_name) return release.name
  const h1 = lines.find((l) => /^# Spree/.test(l))
  return h1 ? h1.slice(2) : `Spree ${release.tag_name.slice(1)}`
}

// Only change lines credit an author, so "configured by @someone" in prose doesn't.
function contributorsOf(release) {
  const bullets = []
  let inFence = false
  for (const line of (release.body || '').split('\n')) {
    if (line.trim().startsWith('```')) inFence = !inFence
    else if (!inFence && /^\s*[-*] /.test(line)) bullets.push(line)
  }
  return [...new Set(bullets.flatMap((l) => [...l.matchAll(/\bby \[?@([\w-]+)/g)].map((m) => m[1])))]
}

async function discordIds() {
  const { readFile } = await import('node:fs/promises')
  const file = new URL('../.github/discord-contributors.json', import.meta.url)
  try {
    const ids = JSON.parse(await readFile(file, 'utf8'))
    return ids && typeof ids === 'object' && !Array.isArray(ids) ? ids : {}
  } catch (error) {
    if (error.code === 'ENOENT') return {}
    throw error
  }
}

// Pings only the mapped contributors; nothing else in the notes can mention anyone.
// Ids must be strings: a JSON number this long loses precision and would ping someone else.
export function thanks(contributors, ids) {
  const byLogin = new Map(Object.entries(ids).map(([login, id]) => [login.toLowerCase(), id]))
  const users = [...new Set(contributors.map((c) => byLogin.get(c.toLowerCase())))]
    .filter((id) => typeof id === 'string' && /^\d{17,20}$/.test(id))
    .slice(0, 80)
  if (!users.length) return { allowed_mentions: { parse: [] } }
  return {
    content: `🙌 Thanks ${users.map((id) => `<@${id}>`).join(' ')} for contributing to this release!`,
    allowed_mentions: { parse: [], users },
  }
}

// The first sentence of a bullet, without its pull request links and author.
function summary(bullet) {
  const text = bullet
    .replace(/\s+/g, ' ')
    .replace(/,? ?\[#\d+\]\([^)\s]{0,300}\)/g, '')
    .replace(/ by \[?@[\w-]+\]?(\([^)\s]{0,300}\))?/g, '')
    .replace(/\[([^\]]{0,300})\]\([^)\s]{0,300}\)/g, '$1')
    .replace(/ in$/, '')
    .trim()
  // A sentence ends before a capital letter, code or emphasis, never after e.g., i.e. or vs.
  const sentence = text.match(/^.+?(?<!\b(?:e\.g|i\.e|vs|etc))[.!?](?= +[\p{Lu}`*_]| *$)/u)?.[0] ?? text
  let short = sentence.replace(/[.]$/, '')
  const open = (text) => (text.match(/`/g) || []).length % 2
  if (short.length > MAX_SUMMARY) {
    const cut = short.lastIndexOf(' ', MAX_SUMMARY - 3)
    short = `${short.slice(0, cut > 0 ? cut : MAX_SUMMARY - 3)}…`
  }
  // Never leave a code span open.
  if (open(short)) short = `${short.replace(/…$/, '')}\`…`
  return short
}

// Whole items only, ending with "and N more" when they don't all fit in max characters.
function joinFitting(items, max, separator = ' · ') {
  const shown = []
  for (const item of items) {
    const rest = items.length - shown.length - 1
    if ([...shown, item].join(separator).length + (rest ? ` and ${rest} more`.length : 0) > max) break
    shown.push(item)
  }
  const more = items.length - shown.length
  return shown.join(separator) + (more ? `${shown.length ? ' and' : ''} ${more} more` : '')
}

function list(items) {
  const shown = items.slice(0, MAX_TITLES).map((t) => `• ${t}`)
  if (items.length > MAX_TITLES) shown.push(`…and ${items.length - MAX_TITLES} more`)
  return clip(shown.join('\n'), 1024)
}

// Characters Discord counts toward the embed limit.
function size({ title = '', description = '', author, name = '', value = '' }) {
  return title.length + description.length + (author?.name.length ?? 0) + name.length + value.length
}

function clip(text, max) {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text
}
