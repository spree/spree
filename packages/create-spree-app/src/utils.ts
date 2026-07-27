import crypto from 'node:crypto'
import { execa, execaCommand } from 'execa'
import type { PackageManager } from './types.js'

/**
 * Pick the package manager for the generated project. An explicit invoking
 * agent wins (`pnpm create spree-app` → pnpm, `yarn create` → yarn).
 * Otherwise — including plain `npx create-spree-app`, where the npm user
 * agent signals the default runner rather than a choice — prefer pnpm when
 * it's installed: it's what the Spree packages and docs are built around
 * (strict peer resolution, single-instance dedupe). Fall back to npm when
 * pnpm isn't available; `--use-npm`/`--use-yarn`/`--use-pnpm` override
 * everything.
 */
export async function detectPackageManager(): Promise<PackageManager> {
  const agent = process.env.npm_config_user_agent ?? ''
  if (agent.startsWith('yarn')) return 'yarn'
  if (agent.startsWith('pnpm')) return 'pnpm'
  return (await isPnpmAvailable()) ? 'pnpm' : 'npm'
}

async function isPnpmAvailable(): Promise<boolean> {
  try {
    await execa('pnpm', ['--version'], { stdio: 'ignore' })
    return true
  } catch {
    return false
  }
}

export async function isDockerRunning(): Promise<boolean> {
  try {
    await execaCommand('docker info', { stdio: 'ignore' })
    return true
  } catch {
    return false
  }
}

export function generateSecretKeyBase(): string {
  return crypto.randomBytes(64).toString('hex')
}

export function installCommand(pm: PackageManager): string {
  return pm === 'yarn' ? 'yarn' : `${pm} install`
}

/**
 * Package manager for commands run inside `apps/storefront/`. The storefront
 * template pins pnpm via `packageManager`, which corepack-managed Yarn
 * refuses to run against — and the same corepack setup provisions the pinned
 * pnpm on demand, so yarn scaffolds use pnpm there. npm ignores the pin and
 * keeps working (and `--use-npm` machines often have no pnpm to fall back to).
 */
export function storefrontPm(pm: PackageManager): PackageManager {
  return pm === 'yarn' ? 'pnpm' : pm
}

/** Runner for a locally-installed bin (e.g. `npx spree`, `pnpm spree`). */
export function runCommand(pm: PackageManager): string {
  if (pm === 'npm') return 'npx'
  if (pm === 'yarn') return 'yarn'
  return 'pnpm'
}

/** Runner for a one-off remote package (e.g. `npx skills`, `pnpm dlx skills`). */
export function dlxCommand(pm: PackageManager): string {
  if (pm === 'npm') return 'npx'
  if (pm === 'yarn') return 'yarn dlx'
  return 'pnpm dlx'
}

/** Global-install command for a package (e.g. `npm install -g`, `pnpm add -g`). */
export function globalAddCommand(pm: PackageManager): string {
  if (pm === 'npm') return 'npm install -g'
  if (pm === 'yarn') return 'yarn global add'
  return 'pnpm add -g'
}
