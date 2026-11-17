// Publishes a patch release once its release pull request has merged and CI
// passed on the merge commit. Run by release-on-merge.yml; a minor, major or
// prerelease is left to a human (`/release`, phase 5).
//
//   SHA=<merge sha> CI_RUN_ID=<CI run id> SUBJECT=<commit subject> \
//     node scripts/release/publish-on-merge.mjs
//
// In order, it tags the merge commit `v<version>` and runs release.yml on the
// tag, waits for `@spree/docs` on npm, then tags and releases `@spree/cli` and
// `create-spree-app` when their versions are not on npm yet, creates the GitHub
// release from the notes in the pull request's description, and starts
// discord-release.yml. Tags made with the workflow's token start no workflow,
// so it starts release.yml itself; that keeps release.yml the workflow npm and
// RubyGems see, which Trusted Publishing needs. Every step skips what already
// exists, so a failed run is re-run as it is.
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { isPublished, manifest, TOOLS, workspacePackages } from '../publish-packages.mjs'
import { gemVersion, npmVersion } from '../version-packages.mjs'
import { read, repoRoot, retry, run } from './lib.mjs'

const { GITHUB_REPOSITORY: repo, SHA: sha, CI_RUN_ID: ciRunId, SUBJECT: subject } = process.env

const api = (endpoint, ...args) => JSON.parse(read('gh', ['api', endpoint, ...args]) || 'null')

/** Null only when GitHub answers 404; any other failure stops the run. */
function apiOrNull(endpoint) {
  try {
    const out = execFileSync('gh', ['api', endpoint], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    return JSON.parse(out)
  } catch (error) {
    if (String(error.stderr).includes('HTTP 404')) return null
    throw error
  }
}

const parseVersion = (tag) => tag.replace(/^v/, '').split('.').map(Number)

function isNewer(version, than) {
  const [a, b] = [parseVersion(version), parseVersion(than)]
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if ((a[i] ?? 0) !== (b[i] ?? 0)) return (a[i] ?? 0) > (b[i] ?? 0)
  }
  return false
}

/** The commit a tag points at, or null when there is no such tag. */
function taggedCommit(tag) {
  const ref = apiOrNull(`repos/${repo}/git/ref/tags/${tag}`)
  if (!ref) return null
  if (ref.object.type === 'commit') return ref.object.sha
  return api(`repos/${repo}/git/tags/${ref.object.sha}`).object.sha
}

function ensureTag(tag) {
  const commit = taggedCommit(tag)
  if (commit === sha) return console.log(`${tag} already tags ${sha}.`)
  if (commit) throw new Error(`${tag} already tags ${commit}, not the merge commit ${sha}.`)
  api(`repos/${repo}/git/refs`, '-f', `ref=refs/tags/${tag}`, '-f', `sha=${sha}`)
  console.log(`Tagged ${sha} as ${tag}.`)
}

const workflowRuns = (workflow, query) =>
  read('gh', [
    'api',
    '--paginate',
    '--jq',
    '.workflow_runs[]',
    `repos/${repo}/actions/workflows/${workflow}/runs?per_page=100&${query}`,
  ])
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line))

/**
 * Starts `workflow` on `ref` and returns the new run's id, which the dispatch
 * returns when asked, so the run is never guessed from a list.
 */
function dispatch(workflow, ref, inputs = {}) {
  const fields = Object.entries(inputs).flatMap(([key, value]) => ['-f', `inputs[${key}]=${value}`])
  const response = api(
    `repos/${repo}/actions/workflows/${workflow}/dispatches`,
    '-X',
    'POST',
    '-f',
    `ref=${ref}`,
    '-F',
    'return_run_details=true',
    ...fields,
  )
  if (!response?.workflow_run_id)
    throw new Error(`GitHub started ${workflow} on ${ref} without a run id.`)
  return response.workflow_run_id
}

function watch(id, what) {
  const url = `https://github.com/${repo}/actions/runs/${id}`
  console.log(`Waiting for ${what}: ${url}`)
  try {
    run('gh', ['run', 'watch', String(id), '--repo', repo, '--exit-status', '--interval', '30'])
  } catch {
    throw new Error(`${what} failed. Re-run its failed jobs (${url}), then re-run this job.`)
  }
}

/** Runs release.yml on `tag` unless a run on it already succeeded; waits for one in progress. */
function release(tag) {
  const runs = workflowRuns('release.yml', `branch=${encodeURIComponent(tag)}`)
  if (runs.some((run) => run.conclusion === 'success')) {
    return console.log(`release.yml already succeeded on ${tag}.`)
  }
  const active = runs.find((run) => run.status !== 'completed')
  watch(active?.id ?? dispatch('release.yml', tag), `release.yml on ${tag}`)
}

/** The CI run covered the backend: every release commit changes Spree::VERSION. */
function checkBackendRan() {
  const { jobs } = api(`repos/${repo}/actions/runs/${ciRunId}/jobs?filter=latest&per_page=100`)
  const backend = jobs.filter((job) => job.name.startsWith('Backend / '))
  if (backend.length === 0) throw new Error(`CI run ${ciRunId} ran no backend suite.`)
  const failed = backend.filter((job) => job.conclusion !== 'success')
  if (failed.length > 0) {
    throw new Error(`CI run ${ciRunId}: ${failed.map((job) => job.name).join(', ')} did not pass.`)
  }
}

/** The release notes between the markers in the pull request's description. */
function releaseNotes(number, version) {
  const pr = api(`repos/${repo}/pulls/${number}`)
  if (!pr.merged_at || pr.merge_commit_sha !== sha) {
    throw new Error(`Pull request #${number} did not merge as ${sha}.`)
  }
  // A description edited on github.com comes back with CRLF line endings.
  const lines = (pr.body ?? '').replaceAll('\r', '').split('\n')
  const start = lines.indexOf('<!-- release-notes -->')
  const end = lines.indexOf('<!-- /release-notes -->', start)
  const notes =
    start === -1 || end === -1
      ? ''
      : lines
          .slice(start + 1, end)
          .join('\n')
          .trim()
  if (!notes.startsWith(`# Spree ${version}\n`) || !/\*\*Full Changelog:\*\*.*$/.test(notes)) {
    throw new Error(
      `Pull request #${number} has no release notes between <!-- release-notes --> markers that start ` +
        `with "# Spree ${version}" and end with the **Full Changelog** line.`,
    )
  }
  return notes
}

function createRelease(tag, notes) {
  if (apiOrNull(`repos/${repo}/releases/tags/${tag}`)) {
    return console.log(`The GitHub release ${tag} already exists.`)
  }
  const latest = apiOrNull(`repos/${repo}/releases/latest`)?.tag_name
  // Only a stable Spree release is compared; anything else (say, a tool's
  // release marked latest by hand) gives way to this one.
  const isLatest = !latest || !/^v\d+\.\d+\.\d+$/.test(latest) || isNewer(tag, latest)
  const notesFile = path.join(repoRoot, 'tmp', `release-notes-${tag.slice(1)}.md`)
  fs.mkdirSync(path.dirname(notesFile), { recursive: true })
  fs.writeFileSync(notesFile, `${notes}\n`)
  run('gh', [
    'release',
    'create',
    tag,
    '--repo',
    repo,
    '--verify-tag',
    '--title',
    tag,
    '--notes-file',
    notesFile,
    `--latest=${isLatest}`,
  ])
}

/** A release created with the workflow's token starts no workflow, so this posts it. */
function postToDiscord(tag) {
  const title = `Post ${tag} to changelog`
  const runs = workflowRuns('discord-release.yml', '').filter((run) => run.display_title === title)
  if (runs.some((run) => run.conclusion === 'success')) {
    return console.log(`${tag} is already posted to Discord.`)
  }
  const active = runs.find((run) => run.status !== 'completed')
  watch(
    active?.id ?? dispatch('discord-release.yml', 'main', { tag, channel: 'changelog' }),
    `the Discord post of ${tag}`,
  )
}

function main() {
  const match = subject?.split('\n')[0].match(/^Released Spree (\S+) \(#(\d+)\)$/)
  if (!match) throw new Error(`Not a release pull request's merge commit: ${subject}`)
  const [, version, number] = match
  if (version !== gemVersion()) {
    throw new Error(`The commit names Spree ${version}, but Spree::VERSION is ${gemVersion()}.`)
  }
  if (!/^\d+\.\d+\.[1-9]\d*$/.test(version)) {
    return console.log(
      `::notice::Spree ${version} is not a patch release, so a human publishes it (/release, phase 5).`,
    )
  }

  checkBackendRan()
  // Read before anything is tagged, so a problem with the notes stops the release while nothing has happened.
  const notes = releaseNotes(number, version)
  const tag = `v${version}`

  ensureTag(tag)
  release(tag)

  // The tools need the docs this release published: `create-spree-app`
  // projects depend on `@spree/docs`, and `spree upgrade` moves it to the
  // server's version.
  retry('@spree/docs on npm', () => isPublished('@spree/docs', npmVersion(version)))
  const tools = TOOLS.map((name) => {
    const { version: toolVersion } = manifest(workspacePackages().get(name))
    return { name, tag: `${name}@${toolVersion}`, published: isPublished(name, toolVersion) }
  })
  const pending = tools.filter(({ published }) => !published)
  for (const { tag: toolTag } of tools.filter(({ published }) => published)) {
    console.log(`${toolTag} is already on npm.`)
  }
  // The first CLI to look for this release's agent skills must find them.
  if (
    pending.length > 0 &&
    !read('git', [
      'ls-remote',
      '--tags',
      'https://github.com/spree/agent-skills.git',
      `refs/tags/${tag}`,
    ]).trim()
  ) {
    throw new Error(
      `spree/agent-skills has no ${tag} tag yet. Tag it (/release, phase 4), then re-run this job.`,
    )
  }
  for (const { tag: toolTag } of pending) {
    ensureTag(toolTag)
    release(toolTag)
  }

  createRelease(tag, notes)
  postToDiscord(tag)
}

main()
