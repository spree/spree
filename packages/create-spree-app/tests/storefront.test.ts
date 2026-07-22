import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { adaptStorefrontWorkflow, prepareStorefrontTemplate } from '../src/storefront'

// Trimmed mirror of the storefront's .github/workflows/ci.yml: a multi-job
// workflow named "CI" whose E2E job boots the stock Spree image via compose.
const STOREFRONT_CI = `name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint

  e2e:
    name: E2E (Playwright + Spree)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - name: Boot Spree backend (Postgres + Redis + latest Spree)
        run: docker compose -f e2e-backend/docker-compose.yml up -d --wait
      - name: Run Playwright tests
        run: npm run test:e2e
`

describe('adaptStorefrontWorkflow', () => {
  it('renames the workflow so it does not shadow the backend CI', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    expect(result).toContain('name: Storefront CI')
    expect(result).not.toMatch(/^name:\s*CI\s*$/m)
  })

  it('runs every job from apps/storefront via a per-job default', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    // Both jobs (lint + e2e) get the working-directory default.
    expect(result.match(/working-directory: apps\/storefront/g)?.length).toBe(2)
    expect(result).toContain(
      '    runs-on: ubuntu-latest\n' +
        '\n' +
        '    defaults:\n' +
        '      run:\n' +
        '        working-directory: apps/storefront',
    )
  })

  it('builds the project backend image before booting the E2E stack', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    expect(result).toContain(
      '- name: Build project backend image\n' +
        '        run: docker build -t project-spree:e2e "$GITHUB_WORKSPACE/backend"',
    )
    // Build step comes before the boot step.
    expect(result.indexOf('Build project backend image')).toBeLessThan(
      result.indexOf('Boot Spree backend'),
    )
  })

  it('boots the E2E stack against the project image via SPREE_IMAGE', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    expect(result).toContain(
      '- name: Boot Spree backend (project backend image)\n' +
        '        env:\n' +
        '          SPREE_IMAGE: project-spree:e2e\n' +
        '        run: docker compose -f e2e-backend/docker-compose.yml up -d --wait',
    )
  })

  it('leaves the Playwright run command unchanged', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    expect(result).toContain('run: npm run test:e2e')
  })
})

describe('prepareStorefrontTemplate', () => {
  const tempDirs: string[] = []

  function seedClonedStorefront(): string {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-storefront-'))
    tempDirs.push(projectDir)

    const workflows = path.join(projectDir, 'apps', 'storefront', '.github', 'workflows')
    fs.mkdirSync(workflows, { recursive: true })
    fs.writeFileSync(path.join(workflows, 'ci.yml'), STOREFRONT_CI)

    return projectDir
  }

  afterEach(() => {
    for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true })
    tempDirs.length = 0
  })

  it('relocates the CI workflow to the project root as storefront-ci.yml', () => {
    const projectDir = seedClonedStorefront()
    prepareStorefrontTemplate(projectDir)

    const moved = path.join(projectDir, '.github', 'workflows', 'storefront-ci.yml')
    expect(fs.existsSync(moved)).toBe(true)
    const content = fs.readFileSync(moved, 'utf-8')
    expect(content).toContain('name: Storefront CI')
    expect(content).toContain('SPREE_IMAGE: project-spree:e2e')
  })

  it("drops the storefront's nested .github after relocating", () => {
    const projectDir = seedClonedStorefront()
    prepareStorefrontTemplate(projectDir)

    expect(fs.existsSync(path.join(projectDir, 'apps', 'storefront', '.github'))).toBe(false)
  })

  it('is a no-op when the storefront ships no workflows', () => {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-storefront-'))
    tempDirs.push(projectDir)
    fs.mkdirSync(path.join(projectDir, 'apps', 'storefront'), { recursive: true })

    expect(() => prepareStorefrontTemplate(projectDir)).not.toThrow()
    expect(fs.existsSync(path.join(projectDir, '.github'))).toBe(false)
  })
})
