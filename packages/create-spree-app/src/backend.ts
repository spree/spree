import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { BACKEND_REPO } from './constants.js'

// Starter paths (relative to backend/) that don't belong in a generated
// project: the wrapper ships its own root README, and release.yml publishes the
// official Spree image. Dropped before the CI workflow is relocated.
const SKIP_BACKEND_PATHS = ['README.md', '.github/workflows/release.yml']

/**
 * Clone the spree-starter backend into `<projectDir>/backend` for the wrapper
 * project's nested layout. Besides fetching the repo, this drops the clone's
 * git metadata and delegates to {@link prepareBackendTemplate}, which relocates
 * the CI workflow to the project root and removes starter-only files — callers
 * get a ready-to-use `backend/`, not a verbatim checkout.
 *
 * @param projectDir absolute path to the wrapper project root
 */
export async function downloadBackend(projectDir: string): Promise<void> {
  const backendDir = path.join(projectDir, 'backend')
  await execa('git', ['clone', '--depth', '1', BACKEND_REPO, backendDir], { stdio: 'ignore' })
  fs.rmSync(path.join(backendDir, '.git'), { recursive: true, force: true })

  prepareBackendTemplate(projectDir)
}

/**
 * Tidy the freshly-cloned starter for the nested `backend/` layout: drop files
 * the wrapper project supplies itself, relocate the CI workflow to the repo
 * root (where GitHub Actions runs it) adapted to run against backend/, and
 * relocate the Render Blueprint likewise (adapted so each service builds from
 * backend/).
 */
export function prepareBackendTemplate(projectDir: string): void {
  const backendDir = path.join(projectDir, 'backend')

  for (const relPath of SKIP_BACKEND_PATHS) {
    fs.rmSync(path.join(backendDir, relPath), { recursive: true, force: true })
  }

  const srcWorkflows = path.join(backendDir, '.github', 'workflows')
  if (fs.existsSync(srcWorkflows)) {
    const destWorkflows = path.join(projectDir, '.github', 'workflows')
    fs.mkdirSync(destWorkflows, { recursive: true })

    for (const file of fs.readdirSync(srcWorkflows)) {
      const content = fs.readFileSync(path.join(srcWorkflows, file), 'utf-8')
      fs.writeFileSync(path.join(destWorkflows, file), adaptWorkflowForNestedBackend(content))
    }

    // Drop the starter's whole .github — its only non-workflow file is a
    // dependabot.yml scoped to the standalone starter repo, which the wrapper
    // replaces with its own root .github/dependabot.yml (covering /, /backend,
    // and the storefront). Keeping it would leave a stale, duplicate config.
    fs.rmSync(path.join(backendDir, '.github'), { recursive: true, force: true })
  }

  // Render reads a single Blueprint from the repository root. The starter ships
  // render.yaml authored for a repo where the Rails app *is* the root; left in
  // backend/ it is invisible to Render, and even at the root its services would
  // build from the wrong directory. Relocate it to the project root with
  // `rootDir: backend` on every buildable service.
  const srcRenderYaml = path.join(backendDir, 'render.yaml')
  if (fs.existsSync(srcRenderYaml)) {
    const content = fs.readFileSync(srcRenderYaml, 'utf-8')
    fs.writeFileSync(path.join(projectDir, 'render.yaml'), adaptRenderYamlForNestedBackend(content))
    fs.rmSync(srcRenderYaml, { force: true })
  }
}

/**
 * Rewrite a Ruby/Rails CI workflow so its steps run against the `backend/`
 * subdirectory instead of the repo root. The starter's workflow is authored for
 * a repo where the Rails app *is* the root; once relocated to the wrapper
 * project root it must point at backend/ or `ruby/setup-ruby` fails to find
 * `.ruby-version`/`Gemfile` and the `bin/rails`/`bundle` steps run in the wrong
 * place. Non-Ruby workflows are returned untouched.
 */
export function adaptWorkflowForNestedBackend(content: string): string {
  if (!content.includes('ruby/setup-ruby')) return content

  let result = content

  // Run every `run:` step from backend/ via a job-level default. Anchored on the
  // first `runs-on:` so the block is inserted at the job's indentation.
  result = result.replace(
    /^([ \t]*)runs-on:.*$/m,
    (line, indent) =>
      `${line}\n\n${indent}defaults:\n${indent}  run:\n${indent}    working-directory: backend`,
  )

  // `ruby/setup-ruby` is an action, not a `run:` step, so job defaults don't
  // reach it — point it at backend/ explicitly so bundler-cache and the version
  // file resolve there.
  result = result.replace(
    /^([ \t]*)- uses: ruby\/setup-ruby@[^\n]*\n([ \t]*)with:[ \t]*\n/m,
    (match, _stepIndent, withIndent) => `${match}${withIndent}  working-directory: backend\n`,
  )

  return result
}

/**
 * Rewrite the starter's Render Blueprint so each service that builds from source
 * deploys the `backend/` subdirectory instead of the repo root. The starter
 * authors render.yaml for a repo where the Rails app *is* the root; in the
 * wrapper project the app lives under backend/, so without `rootDir: backend`
 * Render runs `bundle install` at the root (no Gemfile) and the build fails.
 *
 * `rootDir` is added after every `runtime:` line — the marker of a
 * build-from-source service (web, worker) — while managed services (redis,
 * databases) have no runtime and are left untouched. The commented-out worker
 * template is handled too: its `runtime:` line keeps its `#` prefix, so
 * uncommenting the block yields a correctly-rooted worker.
 */
export function adaptRenderYamlForNestedBackend(content: string): string {
  return content.replace(
    /^([ \t]*(?:#[ \t]*)?)runtime:.*$/gm,
    (line, prefix) => `${line}\n${prefix}rootDir: backend`,
  )
}
