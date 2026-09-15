import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { SERVER_REPO } from './constants.js'

// Starter paths (relative to server/) that don't belong in a generated
// project: the wrapper ships its own root README, and release.yml publishes the
// official Spree image. Dropped before the CI workflow is relocated.
const SKIP_SERVER_PATHS = ['README.md', '.github/workflows/release.yml']

/**
 * Clone the spree-starter server into `<projectDir>/server` for the wrapper
 * project's nested layout. Besides fetching the repo, this drops the clone's
 * git metadata and delegates to {@link prepareServerTemplate}, which relocates
 * the CI workflow to the project root and removes starter-only files — callers
 * get a ready-to-use `server/`, not a verbatim checkout.
 *
 * @param projectDir absolute path to the wrapper project root
 */
export async function downloadServer(projectDir: string): Promise<void> {
  const serverDir = path.join(projectDir, 'server')
  await execa('git', ['clone', '--depth', '1', SERVER_REPO, serverDir], { stdio: 'ignore' })
  fs.rmSync(path.join(serverDir, '.git'), { recursive: true, force: true })

  prepareServerTemplate(projectDir)
}

/**
 * Tidy the freshly-cloned starter for the nested `server/` layout: drop files
 * the wrapper project supplies itself, relocate the CI workflow to the repo
 * root (where GitHub Actions runs it) adapted to run against server/, and
 * relocate the Render Blueprint likewise (adapted so each service builds from
 * server/).
 */
export function prepareServerTemplate(projectDir: string): void {
  const serverDir = path.join(projectDir, 'server')

  for (const relPath of SKIP_SERVER_PATHS) {
    fs.rmSync(path.join(serverDir, relPath), { recursive: true, force: true })
  }

  const srcWorkflows = path.join(serverDir, '.github', 'workflows')
  if (fs.existsSync(srcWorkflows)) {
    const destWorkflows = path.join(projectDir, '.github', 'workflows')
    fs.mkdirSync(destWorkflows, { recursive: true })

    for (const file of fs.readdirSync(srcWorkflows)) {
      const content = fs.readFileSync(path.join(srcWorkflows, file), 'utf-8')
      fs.writeFileSync(path.join(destWorkflows, file), adaptWorkflowForNestedServer(content))
    }

    // Drop the starter's whole .github — its only non-workflow file is a
    // dependabot.yml scoped to the standalone starter repo, which the wrapper
    // replaces with its own root .github/dependabot.yml (covering /, /server,
    // and the storefront). Keeping it would leave a stale, duplicate config.
    fs.rmSync(path.join(serverDir, '.github'), { recursive: true, force: true })
  }

  // Render reads a single Blueprint from the repository root. The starter ships
  // The starter authors render.yaml for exactly this project layout (Docker
  // runtime, server/Dockerfile built with the repo root as context, so the
  // ejected server and apps/dashboard ship in one image) — Render just needs
  // it at the repo root where Blueprints are read.
  const srcRenderYaml = path.join(serverDir, 'render.yaml')
  if (fs.existsSync(srcRenderYaml)) {
    fs.renameSync(srcRenderYaml, path.join(projectDir, 'render.yaml'))
  }
}

/**
 * Rewrite a Ruby/Rails CI workflow so its steps run against the `server/`
 * subdirectory instead of the repo root. The starter's workflow is authored for
 * a repo where the Rails app *is* the root; once relocated to the wrapper
 * project root it must point at server/ or `ruby/setup-ruby` fails to find
 * `.ruby-version`/`Gemfile` and the `bin/rails`/`bundle` steps run in the wrong
 * place. Non-Ruby workflows are returned untouched.
 */
export function adaptWorkflowForNestedServer(content: string): string {
  if (!content.includes('ruby/setup-ruby')) return content

  let result = content

  // Run every `run:` step from server/ via a job-level default. Anchored on the
  // first `runs-on:` so the block is inserted at the job's indentation.
  result = result.replace(
    /^([ \t]*)runs-on:.*$/m,
    (line, indent) =>
      `${line}\n\n${indent}defaults:\n${indent}  run:\n${indent}    working-directory: server`,
  )

  // `ruby/setup-ruby` is an action, not a `run:` step, so job defaults don't
  // reach it — point it at server/ explicitly so bundler-cache and the version
  // file resolve there.
  result = result.replace(
    /^([ \t]*)- uses: ruby\/setup-ruby@[^\n]*\n([ \t]*)with:[ \t]*\n/m,
    (match, _stepIndent, withIndent) => `${match}${withIndent}  working-directory: server\n`,
  )

  return result
}
