import { describe, expect, it } from 'vitest'
import { adaptWorkflowForNestedBackend } from '../src/backend'

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
