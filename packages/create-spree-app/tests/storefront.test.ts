import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { adaptStorefrontWorkflow, prepareStorefrontTemplate } from '../src/storefront'

// Trimmed mirror of the storefront's .github/workflows/ci.yml: a multi-job
// pnpm workflow named "CI" whose E2E job boots the stock Spree image via
// compose.
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
      - uses: pnpm/action-setup@0ebf47130e4866e96fce0953f49152a61190b271 # v6.0.9
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm run check

  e2e:
    name: E2E (Playwright + Spree)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@0ebf47130e4866e96fce0953f49152a61190b271 # v6.0.9
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - name: Boot Spree backend (Postgres + Redis + latest Spree)
        run: docker compose -f e2e-backend/docker-compose.yml up -d --wait
      - name: Run Playwright tests
        run: pnpm run test:e2e
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
    expect(result).toContain('run: pnpm run test:e2e')
  })

  it('points pnpm/action-setup at the storefront package.json', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    const expected =
      '      - uses: pnpm/action-setup@0ebf47130e4866e96fce0953f49152a61190b271 # v6.0.9\n' +
      '        with:\n' +
      '          package_json_file: apps/storefront/package.json'
    // Both jobs (lint + e2e) get the rewrite.
    expect(result.split(expected).length - 1).toBe(2)
  })

  it('keys the setup-node cache on the storefront lockfile', () => {
    const result = adaptStorefrontWorkflow(STOREFRONT_CI)
    const expected =
      '          cache: pnpm\n' + '          cache-dependency-path: apps/storefront/pnpm-lock.yaml'
    expect(result.split(expected).length - 1).toBe(2)
  })

  it('keys npm caches on the storefront package-lock (pre-pnpm clones)', () => {
    const legacy = [
      '      - uses: actions/setup-node@v4',
      '        with:',
      '          cache: npm',
    ].join('\n')
    expect(adaptStorefrontWorkflow(legacy)).toContain(
      '          cache: npm\n          cache-dependency-path: apps/storefront/package-lock.json',
    )
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

  it('removes a nested .github even when it has no ci.yml, without creating an empty root workflows dir', () => {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-storefront-'))
    tempDirs.push(projectDir)
    // .github present but no workflows/ci.yml — e.g. only issue templates.
    const github = path.join(projectDir, 'apps', 'storefront', '.github')
    fs.mkdirSync(github, { recursive: true })
    fs.writeFileSync(path.join(github, 'FUNDING.yml'), 'github: [spree]\n')

    prepareStorefrontTemplate(projectDir)

    // Nested metadata is gone …
    expect(fs.existsSync(github)).toBe(false)
    // … and no empty root workflows directory was created.
    expect(fs.existsSync(path.join(projectDir, '.github', 'workflows'))).toBe(false)
  })
})
