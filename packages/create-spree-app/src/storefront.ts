import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { STOREFRONT_REPO } from './constants.js'
import { storefrontEnvContent } from './templates/env.js'
import type { PackageManager } from './types.js'
import { installCommand, storefrontPm } from './utils.js'

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
 * The clone is otherwise left as-is: its `pnpm-lock.yaml` and `packageManager`
 * pin stay even on npm/yarn scaffolds, because the relocated CI is pnpm-based
 * and installs against that lockfile.
 *
 * @param projectDir absolute path to the wrapper project root
 */
export function prepareStorefrontTemplate(projectDir: string): void {
  const storefrontDir = path.join(projectDir, 'apps', 'storefront')
  const srcGithub = path.join(storefrontDir, '.github')

  // Relocate the CI workflow only when it exists — and create the destination
  // dir only then, so we never leave an empty root workflows/ behind.
  const ci = path.join(srcGithub, 'workflows', 'ci.yml')
  if (fs.existsSync(ci)) {
    const destWorkflows = path.join(projectDir, '.github', 'workflows')
    fs.mkdirSync(destWorkflows, { recursive: true })
    const content = fs.readFileSync(ci, 'utf-8')
    // Renamed so it doesn't collide with the backend's relocated `ci.yml`.
    fs.writeFileSync(
      path.join(destWorkflows, 'storefront-ci.yml'),
      adaptStorefrontWorkflow(content),
    )
  }

  // The storefront's `.github` isn't meaningful at the wrapper root; always
  // drop it so no stale, non-running copy is left behind (rmSync with force
  // is a no-op when it's absent).
  fs.rmSync(srcGithub, { recursive: true, force: true })
}

/**
 * Rewrite the storefront CI workflow for the wrapper project's nested layout:
 *
 * - rename it (`CI` → `Storefront CI`) so it doesn't shadow the backend's check;
 * - run every job from `apps/storefront/` via a per-job default;
 * - point `pnpm/action-setup` and setup-node's dependency cache at
 *   `apps/storefront/` — both resolve from the repo root by default, where the
 *   storefront's package.json and lockfile don't exist in this layout;
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

  // pnpm/action-setup reads the pnpm version from `packageManager` in the
  // repo-root package.json; the storefront's copy is the authoritative one
  // here (the wrapper root's may be absent on npm/yarn scaffolds).
  result = result.replace(
    /^([ \t]*)- uses: pnpm\/action-setup@.*$/gm,
    (line, indent) =>
      `${line}\n${indent}  with:\n${indent}    package_json_file: apps/storefront/package.json`,
  )

  // setup-node's cache keys on a lockfile resolved from the repo root, where
  // the storefront's doesn't live in this layout — the job fails outright
  // when the root has no matching lockfile. Handles both the pnpm workflow
  // and pre-pnpm clones still caching npm.
  result = result.replace(
    /^([ \t]*)cache: (npm|pnpm)[ \t]*$/gm,
    (_line, indent, pm) =>
      `${indent}cache: ${pm}\n${indent}cache-dependency-path: apps/storefront/${
        pm === 'pnpm' ? 'pnpm-lock.yaml' : 'package-lock.json'
      }`,
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
  // storefrontPm: never invoke yarn here — corepack-managed Yarn refuses to
  // run inside the pnpm-pinned template.
  const spm = storefrontPm(pm)
  const [cmd, ...args] = installCommand(spm).split(' ')
  // Install exactly the tree the storefront's committed lockfile describes —
  // manifest/lockfile drift in the template should fail this (warn-and-
  // continue) phase loudly, not resolve silently to an untested tree.
  if (spm === 'pnpm') args.push('--frozen-lockfile')
  await execa(cmd, args, { cwd: storefrontDir, stdio: 'ignore' })
}

export function writeStorefrontEnv(projectDir: string, port: number, wholesale = false): void {
  const envPath = path.join(projectDir, 'apps', 'storefront', '.env.local')
  fs.writeFileSync(envPath, storefrontEnvContent(port, wholesale))
}
