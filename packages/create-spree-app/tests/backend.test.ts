import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import {
  adaptRenderYamlForNestedBackend,
  adaptWorkflowForNestedBackend,
  prepareBackendTemplate,
} from '../src/backend'

// Mirrors spree-starter's .github/workflows/backend-ci.yml (the workflow that
// create-spree-app relocates to the generated project root).
const BACKEND_CI = `name: CI

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

// Mirrors spree-starter's render.yaml (the Render Blueprint create-spree-app
// relocates to the generated project root). Includes an active web service, the
// commented-out worker template, a managed redis service, and a database — the
// mix that exercises which services get `rootDir`.
const RENDER_YAML = `services:
  - type: web
    name: spree
    runtime: ruby
    plan: free
    buildCommand: bundle install && bundle exec rails db:prepare
    startCommand: bundle exec puma -C config/puma.rb
    healthCheckPath: /up

  # uncomment to add background jobs, requires standard (paid) plan
  # - type: worker
  #   name: spree-worker
  #   runtime: ruby
  #   plan: standard
  #   buildCommand: bundle install && bundle exec rails assets:precompile
  #   startCommand: bundle exec sidekiq

  - type: redis
    name: spree-redis
    plan: free
    ipAllowList: []

databases:
  - name: spree-db
    plan: free
    databaseName: spree
    ipAllowList: []
`

describe('adaptWorkflowForNestedBackend', () => {
  it('points ruby/setup-ruby at the backend/ subdirectory', () => {
    const result = adaptWorkflowForNestedBackend(BACKEND_CI)
    expect(result).toContain(
      '      - uses: ruby/setup-ruby@v1\n' +
        '        with:\n' +
        '          working-directory: backend\n' +
        '          bundler-cache: true',
    )
  })

  it('runs job steps from backend/ via a job-level default', () => {
    const result = adaptWorkflowForNestedBackend(BACKEND_CI)
    expect(result).toContain(
      '    runs-on: ubuntu-latest\n' +
        '\n' +
        '    defaults:\n' +
        '      run:\n' +
        '        working-directory: backend',
    )
  })

  it('inserts the defaults block exactly once', () => {
    const result = adaptWorkflowForNestedBackend(BACKEND_CI)
    expect(result.match(/defaults:/g)).toHaveLength(1)
  })

  it('leaves the run-step commands unchanged', () => {
    const result = adaptWorkflowForNestedBackend(BACKEND_CI)
    expect(result).toContain('run: bin/rails db:prepare')
    expect(result).toContain('run: bundle exec rspec')
  })

  it('leaves non-Ruby workflows untouched', () => {
    expect(adaptWorkflowForNestedBackend(RELEASE)).toBe(RELEASE)
  })
})

describe('adaptRenderYamlForNestedBackend', () => {
  it('adds rootDir: backend to the buildable web service', () => {
    const result = adaptRenderYamlForNestedBackend(RENDER_YAML)
    expect(result).toContain('    runtime: ruby\n    rootDir: backend\n')
  })

  it('adds a commented rootDir to the commented worker so uncommenting still deploys', () => {
    const result = adaptRenderYamlForNestedBackend(RENDER_YAML)
    expect(result).toContain('  #   runtime: ruby\n  #   rootDir: backend\n')
  })

  it('leaves managed services (redis, databases) untouched', () => {
    const result = adaptRenderYamlForNestedBackend(RENDER_YAML)
    // redis and the database have no runtime, so no rootDir is injected for them
    expect(result.match(/rootDir: backend/g)).toHaveLength(2)
    expect(result).toContain('  - type: redis\n    name: spree-redis\n    plan: free')
    expect(result).toContain('databases:\n  - name: spree-db')
  })
})

describe('prepareBackendTemplate', () => {
  const tempDirs: string[] = []

  function seedClonedBackend(): string {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-backend-'))
    tempDirs.push(projectDir)

    const workflows = path.join(projectDir, 'backend', '.github', 'workflows')
    fs.mkdirSync(workflows, { recursive: true })
    fs.writeFileSync(path.join(workflows, 'backend-ci.yml'), BACKEND_CI)
    fs.writeFileSync(path.join(workflows, 'release.yml'), RELEASE)
    fs.writeFileSync(path.join(projectDir, 'backend', 'README.md'), '# Spree starter')
    fs.writeFileSync(path.join(projectDir, 'backend', 'render.yaml'), RENDER_YAML)

    return projectDir
  }

  afterEach(() => {
    for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true })
    tempDirs.length = 0
  })

  it('relocates the CI workflow to the project root, adapted for backend/', () => {
    const projectDir = seedClonedBackend()
    prepareBackendTemplate(projectDir)

    const moved = path.join(projectDir, '.github', 'workflows', 'backend-ci.yml')
    expect(fs.existsSync(moved)).toBe(true)
    expect(fs.readFileSync(moved, 'utf-8')).toContain('working-directory: backend')
  })

  it('drops the release workflow instead of copying it', () => {
    const projectDir = seedClonedBackend()
    prepareBackendTemplate(projectDir)

    expect(fs.existsSync(path.join(projectDir, '.github', 'workflows', 'release.yml'))).toBe(false)
    expect(fs.existsSync(path.join(projectDir, 'backend', '.github'))).toBe(false)
  })

  it("drops the starter's README", () => {
    const projectDir = seedClonedBackend()
    prepareBackendTemplate(projectDir)

    expect(fs.existsSync(path.join(projectDir, 'backend', 'README.md'))).toBe(false)
  })

  it('relocates render.yaml to the project root with rootDir: backend', () => {
    const projectDir = seedClonedBackend()
    prepareBackendTemplate(projectDir)

    const moved = path.join(projectDir, 'render.yaml')
    expect(fs.existsSync(moved)).toBe(true)
    expect(fs.readFileSync(moved, 'utf-8')).toContain('    runtime: ruby\n    rootDir: backend\n')
    // The original in backend/ is removed so Render never reads a stale copy.
    expect(fs.existsSync(path.join(projectDir, 'backend', 'render.yaml'))).toBe(false)
  })
})
