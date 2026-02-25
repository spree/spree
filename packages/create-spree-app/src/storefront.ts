import { downloadTemplate } from 'giget'
import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { STOREFRONT_REPO } from './constants.js'
import { storefrontEnvContent } from './templates/env.js'
import { installCommand } from './utils.js'
import type { PackageManager } from './types.js'

export async function downloadStorefront(projectDir: string): Promise<void> {
  const storefrontDir = path.join(projectDir, 'apps', 'storefront')
  await downloadTemplate(STOREFRONT_REPO, { dir: storefrontDir, force: true })
}

export async function installStorefrontDeps(projectDir: string, pm: PackageManager): Promise<void> {
  const storefrontDir = path.join(projectDir, 'apps', 'storefront')
  const [cmd, ...args] = installCommand(pm).split(' ')
  await execa(cmd, args, { cwd: storefrontDir, stdio: 'ignore' })
}

export function writeStorefrontEnv(projectDir: string, apiKey?: string): void {
  const envPath = path.join(projectDir, 'apps', 'storefront', '.env.local')
  fs.writeFileSync(envPath, storefrontEnvContent(apiKey))
}
