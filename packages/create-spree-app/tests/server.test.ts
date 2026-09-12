import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { adaptWorkflowForNestedServer, prepareServerTemplate } from '../src/server'

// Mirrors spree-starter's .github/workflows/server-ci.yml (the workflow that
// create-spree-app relocates to the generated project root).
const SERVER_CI = `name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:18

    env:
      RAILS_ENV: test

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Prepare database
        run: bin/rails db:prepare

      - name: Run tests
        run: bundle exec rspec
`

// A non-Ruby workflow (e.g. release.yml) that must be left untouched.
const RELEASE = `name: Release Docker Image

on:
  push:
    tags: ['v*']

jobs:
  release-docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v6
        with:
          context: .
`

// A trimmed render.yaml covering the three shapes the transform distinguishes:
// a buildable service (has `runtime:`), the commented-out worker template
// (`runtime:` behind a `#`), and a managed service (no `runtime:`).
const RENDER_YAML = `services:
  - type: web
    runtime: ruby
    plan: free

  # - type: worker
  #   runtime: ruby
  #   plan: standard

  - type: redis
    name: spree-redis
    plan: free
`

describe('adaptWorkflowForNestedServer', () => {
  it('points ruby/setup-ruby at the server/ subdirectory', () => {
    const result = adaptWorkflowForNestedServer(SERVER_CI)
    expect(result).toContain(
      '      - uses: ruby/setup-ruby@v1\n' +
        '        with:\n' +
        '          working-directory: server\n' +
        '          bundler-cache: true',
    )
  })

  it('runs job steps from server/ via a job-level default', () => {
    const result = adaptWorkflowForNestedServer(SERVER_CI)
    expect(result).toContain(
      '    runs-on: ubuntu-latest\n' +
        '\n' +
        '    defaults:\n' +
        '      run:\n' +
        '        working-directory: server',
    )
  })

  it('inserts the defaults block exactly once', () => {
    const result = adaptWorkflowForNestedServer(SERVER_CI)
    expect(result.match(/defaults:/g)).toHaveLength(1)
  })

  it('leaves the run-step commands unchanged', () => {
    const result = adaptWorkflowForNestedServer(SERVER_CI)
    expect(result).toContain('run: bin/rails db:prepare')
    expect(result).toContain('run: bundle exec rspec')
  })

  it('leaves non-Ruby workflows untouched', () => {
    expect(adaptWorkflowForNestedServer(RELEASE)).toBe(RELEASE)
  })
})

describe('prepareServerTemplate', () => {
  const tempDirs: string[] = []

  function seedClonedServer(): string {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-server-'))
    tempDirs.push(projectDir)

    const workflows = path.join(projectDir, 'server', '.github', 'workflows')
    fs.mkdirSync(workflows, { recursive: true })
    fs.writeFileSync(path.join(workflows, 'server-ci.yml'), SERVER_CI)
    fs.writeFileSync(path.join(workflows, 'release.yml'), RELEASE)
    fs.writeFileSync(path.join(projectDir, 'server', 'README.md'), '# Spree starter')
    fs.writeFileSync(path.join(projectDir, 'server', 'render.yaml'), RENDER_YAML)

    return projectDir
  }

  afterEach(() => {
    for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true })
    tempDirs.length = 0
  })

  it('relocates the CI workflow to the project root, adapted for server/', () => {
    const projectDir = seedClonedServer()
    prepareServerTemplate(projectDir)

    const moved = path.join(projectDir, '.github', 'workflows', 'server-ci.yml')
    expect(fs.existsSync(moved)).toBe(true)
    expect(fs.readFileSync(moved, 'utf-8')).toContain('working-directory: server')
  })

  it('drops the release workflow instead of copying it', () => {
    const projectDir = seedClonedServer()
    prepareServerTemplate(projectDir)

    expect(fs.existsSync(path.join(projectDir, '.github', 'workflows', 'release.yml'))).toBe(false)
    expect(fs.existsSync(path.join(projectDir, 'server', '.github'))).toBe(false)
  })

  it("drops the starter's README", () => {
    const projectDir = seedClonedServer()
    prepareServerTemplate(projectDir)

    expect(fs.existsSync(path.join(projectDir, 'server', 'README.md'))).toBe(false)
  })

  it('relocates render.yaml to the project root verbatim', () => {
    const projectDir = seedClonedServer()
    prepareServerTemplate(projectDir)

    const moved = path.join(projectDir, 'render.yaml')
    expect(fs.existsSync(moved)).toBe(true)
    // Authored by the starter for exactly this layout — no rewriting.
    expect(fs.readFileSync(moved, 'utf-8')).toBe(RENDER_YAML)
    // The original in server/ is removed so Render never reads a stale copy.
    expect(fs.existsSync(path.join(projectDir, 'server', 'render.yaml'))).toBe(false)
  })
})
