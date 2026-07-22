import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { STOREFRONT_REPO } from './constants.js'
import { storefrontEnvContent } from './templates/env.js'
import type { PackageManager } from './types.js'
import { installCommand } from './utils.js'

export async function downloadStorefront(projectDir: string): Promise<void> {
  const storefrontDir = path.join(projectDir, 'apps', 'storefront')
  await execa('git', ['clone', '--depth', '1', STOREFRONT_REPO, storefrontDir], { stdio: 'ignore' })
  fs.rmSync(path.join(storefrontDir, '.git'), { recursive: true, force: true })

  prepareStorefrontTemplate(projectDir)
}

/** Local image tag the generated E2E workflow builds `backend/` into. */
const PROJECT_SPREE_IMAGE = 'project-spree:e2e'

/**
 * Tidy the freshly-cloned storefront for the nested `apps/storefront/` layout:
 * relocate its CI workflow to the project root (adapted to run from
 * apps/storefront, and to build the project's own `backend/` image for the E2E
 * suite instead of stock Spree), and drop the storefront's now-empty `.github`.
 *
 * @param projectDir absolute path to the wrapper project root
 */
export function prepareStorefrontTemplate(projectDir: string): void {
  const storefrontDir = path.join(projectDir, 'apps', 'storefront')
  const srcWorkflows = path.join(storefrontDir, '.github', 'workflows')
  if (!fs.existsSync(srcWorkflows)) return

  const destWorkflows = path.join(projectDir, '.github', 'workflows')
  fs.mkdirSync(destWorkflows, { recursive: true })

  const ci = path.join(srcWorkflows, 'ci.yml')
  if (fs.existsSync(ci)) {
    const content = fs.readFileSync(ci, 'utf-8')
    // Renamed so it doesn't collide with the backend's relocated `ci.yml`.
    fs.writeFileSync(
      path.join(destWorkflows, 'storefront-ci.yml'),
      adaptStorefrontWorkflow(content),
    )
  }

  // The storefront's other workflows aren't meaningful at the wrapper root;
  // drop the whole `.github` so no stale, non-running copy is left behind.
  fs.rmSync(path.join(storefrontDir, '.github'), { recursive: true, force: true })
}

/**
 * Rewrite the storefront CI workflow for the wrapper project's nested layout:
 *
 * - rename it (`CI` → `Storefront CI`) so it doesn't shadow the backend's check;
 * - run every job from `apps/storefront/` via a per-job default;
 * - in the E2E job, build the project's own `backend/Dockerfile` into a local
 *   image and boot the E2E stack against it (`SPREE_IMAGE`), so the storefront
 *   is tested against the customized backend the project deploys — not stock
 *   Spree.
 */
export function adaptStorefrontWorkflow(content: string): string {
  let result = content

  // Disambiguate the workflow name from the backend's "CI".
  result = result.replace(/^name:\s*CI\s*$/m, 'name: Storefront CI')

  // Run every job's `run:` steps from apps/storefront. Anchored on each
  // `runs-on:` so the default is inserted at each job's indentation.
  result = result.replace(
    /^([ \t]*)runs-on:.*$/gm,
    (line, indent) =>
      `${line}\n\n${indent}defaults:\n${indent}  run:\n${indent}    working-directory: apps/storefront`,
  )

  // The E2E "Boot Spree backend" step must run against the project's own
  // backend image. Insert a build step just before it (building the repo-root
  // `backend/` — checkout clones the whole project, so it's a sibling of
  // apps/storefront), and set SPREE_IMAGE on the boot step's env.
  result = result.replace(
    /^([ \t]*)- name: Boot Spree backend[^\n]*\n([ \t]*)run: (.*)$/m,
    (_match, stepIndent, runIndent, runCmd) => {
      const build =
        `${stepIndent}- name: Build project backend image\n` +
        // working-directory default targets apps/storefront, so reach the
        // sibling backend/ via the workspace root.
        `${runIndent}run: docker build -t ${PROJECT_SPREE_IMAGE} "$GITHUB_WORKSPACE/backend"\n`
      const boot =
        `${stepIndent}- name: Boot Spree backend (project backend image)\n` +
        `${runIndent}env:\n` +
        `${runIndent}  SPREE_IMAGE: ${PROJECT_SPREE_IMAGE}\n` +
        `${runIndent}run: ${runCmd}`
      return `${build}${boot}`
    },
  )

  return result
}

export async function installRootDeps(projectDir: string, pm: PackageManager): Promise<void> {
  const [cmd, ...args] = installCommand(pm).split(' ')
  await execa(cmd, args, { cwd: projectDir, stdio: 'ignore' })
}

export async function installStorefrontDeps(projectDir: string, pm: PackageManager): Promise<void> {
  const storefrontDir = path.join(projectDir, 'apps', 'storefront')
  const [cmd, ...args] = installCommand(pm).split(' ')
  await execa(cmd, args, { cwd: storefrontDir, stdio: 'ignore' })
}

export function writeStorefrontEnv(projectDir: string, port: number, apiKey?: string): void {
  const envPath = path.join(projectDir, 'apps', 'storefront', '.env.local')
  fs.writeFileSync(envPath, storefrontEnvContent(port, apiKey))
}
