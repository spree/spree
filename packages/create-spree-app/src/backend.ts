import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { BACKEND_REPO } from './constants.js'

// Starter files that are redundant once the app is nested under backend/: the
// wrapper project ships its own root README, and the release workflow publishes
// the official Spree image and has no place in a generated project.
const SKIP_BACKEND_FILES = ['README.md']
const SKIP_BACKEND_WORKFLOWS = ['release.yml']

export async function downloadBackend(projectDir: string): Promise<void> {
  const backendDir = path.join(projectDir, 'backend')
  await execa('git', ['clone', '--depth', '1', BACKEND_REPO, backendDir], { stdio: 'ignore' })
  fs.rmSync(path.join(backendDir, '.git'), { recursive: true, force: true })

  prepareBackendTemplate(projectDir)
}

/**
 * Tidy the freshly-cloned starter for the nested `backend/` layout: drop files
 * the wrapper project supplies itself, and relocate the CI workflow to the repo
 * root (where GitHub Actions runs it) adapted to run against backend/.
 */
export function prepareBackendTemplate(projectDir: string): void {
  const backendDir = path.join(projectDir, 'backend')

  for (const file of SKIP_BACKEND_FILES) {
    fs.rmSync(path.join(backendDir, file), { force: true })
  }

  const srcWorkflows = path.join(backendDir, '.github', 'workflows')
  if (fs.existsSync(srcWorkflows)) {
    const destWorkflows = path.join(projectDir, '.github', 'workflows')
    fs.mkdirSync(destWorkflows, { recursive: true })

    for (const file of fs.readdirSync(srcWorkflows)) {
      if (SKIP_BACKEND_WORKFLOWS.includes(file)) continue
      const content = fs.readFileSync(path.join(srcWorkflows, file), 'utf-8')
      fs.writeFileSync(path.join(destWorkflows, file), adaptWorkflowForNestedBackend(content))
    }

    fs.rmSync(path.join(backendDir, '.github'), { recursive: true, force: true })
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
