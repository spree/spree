import * as p from '@clack/prompts'
import pc from 'picocolors'
import fs from 'node:fs'
import path from 'node:path'
import type { ScaffoldOptions } from './types.js'
import { SPREE_PORT, STOREFRONT_PORT, DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from './constants.js'
import { generateSecretKeyBase, isDockerRunning } from './utils.js'
import { dockerComposeContent } from './templates/docker-compose.js'
import { envContent } from './templates/env.js'
import { rootPackageJsonContent } from './templates/package-json.js'
import { readmeContent } from './templates/readme.js'
import { gitignoreContent } from './templates/gitignore.js'
import { startServices, waitForHealthy, fetchApiKey, loadSampleData } from './docker.js'
import { downloadStorefront, installStorefrontDeps, writeStorefrontEnv } from './storefront.js'

export async function scaffold(options: ScaffoldOptions): Promise<void> {
  const projectDir = path.resolve(options.directory)
  const projectName = path.basename(projectDir)
  const isFullStack = options.mode === 'full-stack'

  // Pre-flight checks
  if (options.start) {
    const dockerRunning = await isDockerRunning()
    if (!dockerRunning) {
      p.cancel('Docker is not running. Please start Docker and try again, or use --no-start.')
      process.exit(1)
    }
  }

  if (fs.existsSync(projectDir)) {
    const entries = fs.readdirSync(projectDir)
    if (entries.length > 0) {
      p.cancel(`Directory ${pc.bold(options.directory)} is not empty.`)
      process.exit(1)
    }
  }

  // Phase 1: Generate project files
  const s = p.spinner()

  s.start('Creating project structure...')

  fs.mkdirSync(projectDir, { recursive: true })
  fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), dockerComposeContent())
  fs.writeFileSync(path.join(projectDir, '.env'), envContent(generateSecretKeyBase()))
  fs.writeFileSync(path.join(projectDir, 'package.json'), rootPackageJsonContent(projectName))
  fs.writeFileSync(path.join(projectDir, 'README.md'), readmeContent(projectName, isFullStack))
  fs.writeFileSync(path.join(projectDir, '.gitignore'), gitignoreContent())

  s.stop('Project structure created.')

  // Phase 2: Storefront
  if (isFullStack) {
    s.start('Downloading storefront template...')
    await downloadStorefront(projectDir)
    s.stop('Storefront template downloaded.')

    writeStorefrontEnv(projectDir)

    s.start('Installing storefront dependencies...')
    await installStorefrontDeps(projectDir, options.packageManager)
    s.stop('Storefront dependencies installed.')
  }

  // Phase 3: Docker
  if (options.start) {
    s.start('Starting Docker services...')
    await startServices(projectDir)
    s.stop('Docker services started.')

    s.start('Waiting for Spree to be ready...')
    await waitForHealthy()
    s.stop('Spree is ready.')

    let apiKey: string | undefined

    s.start('Configuring API key...')
    apiKey = await fetchApiKey(projectDir)
    s.stop(`API key: ${pc.cyan(apiKey)}`)

    if (isFullStack && apiKey) {
      writeStorefrontEnv(projectDir, apiKey)
    }

    if (options.sampleData) {
      s.start('Loading sample data...')
      await loadSampleData(projectDir)
      s.stop('Sample data loaded.')
    }

    printSuccessWithDocker(projectDir, projectName, isFullStack, apiKey)
  } else {
    printSuccessWithoutDocker(projectDir, projectName, isFullStack)
  }
}

function printSuccessWithDocker(
  _projectDir: string,
  projectName: string,
  isFullStack: boolean,
  apiKey?: string,
): void {
  const lines: string[] = [
    '',
    `${pc.bold('Admin Dashboard')}`,
    `  ${pc.cyan(`http://localhost:${SPREE_PORT}/admin`)}`,
    `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
    `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
  ]

  if (isFullStack) {
    lines.push(
      '',
      `${pc.bold('Storefront')}`,
      `  Run:  ${pc.cyan(`cd ${projectName}/apps/storefront && npm run dev`)}`,
      `  Open: ${pc.cyan(`http://localhost:${STOREFRONT_PORT}`)}`,
    )
  }

  lines.push(
    '',
    `${pc.bold('Store API')}`,
    `  ${pc.cyan(`http://localhost:${SPREE_PORT}/api/v3/store`)}`,
  )

  if (apiKey) {
    lines.push(`  API Key: ${pc.cyan(apiKey)}`)
  }

  p.note(lines.join('\n'), 'Your Spree store is ready!')
}

function printSuccessWithoutDocker(
  _projectDir: string,
  projectName: string,
  isFullStack: boolean,
): void {
  const lines: string[] = [
    '',
    `${pc.bold('Next steps:')}`,
    `  cd ${projectName}`,
    `  docker compose up -d`,
  ]

  if (isFullStack) {
    lines.push(
      '',
      `  ${pc.dim('# In another terminal:')}`,
      `  cd ${projectName}/apps/storefront`,
      `  npm install`,
      `  npm run dev`,
    )
  }

  lines.push(
    '',
    `${pc.bold('Admin Dashboard')}`,
    `  http://localhost:${SPREE_PORT}/admin`,
    `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
    `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
  )

  p.note(lines.join('\n'), 'Project created!')
}
