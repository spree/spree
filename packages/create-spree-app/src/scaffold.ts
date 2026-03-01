import * as p from '@clack/prompts'
import pc from 'picocolors'
import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import type { ScaffoldOptions } from './types.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from './constants.js'
import { generateSecretKeyBase, isDockerRunning } from './utils.js'
import { dockerComposeContent } from './templates/docker-compose.js'
import { envContent } from './templates/env.js'
import { rootPackageJsonContent } from './templates/package-json.js'
import { readmeContent } from './templates/readme.js'
import { gitignoreContent } from './templates/gitignore.js'
import { downloadStorefront, installStorefrontDeps, installRootDeps, writeStorefrontEnv } from './storefront.js'

export async function scaffold(options: ScaffoldOptions): Promise<void> {
  const projectDir = path.resolve(options.directory)
  const projectName = path.basename(projectDir)
  const isFullStack = options.mode === 'full-stack'
  const { port } = options

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
  fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), dockerComposeContent(port))
  fs.writeFileSync(path.join(projectDir, '.env'), envContent(generateSecretKeyBase(), port))
  fs.writeFileSync(path.join(projectDir, 'package.json'), rootPackageJsonContent(projectName))
  fs.writeFileSync(path.join(projectDir, 'README.md'), readmeContent(projectName, isFullStack, port))
  fs.writeFileSync(path.join(projectDir, '.gitignore'), gitignoreContent())

  s.stop('Project structure created.')

  // Install root dependencies (@spree/cli)
  s.start('Installing dependencies...')
  await installRootDeps(projectDir, options.packageManager)
  s.stop('Dependencies installed.')

  // Phase 2: Storefront
  if (isFullStack) {
    s.start('Downloading storefront template...')
    await downloadStorefront(projectDir)
    s.stop('Storefront template downloaded.')

    writeStorefrontEnv(projectDir, port)

    s.start('Installing storefront dependencies...')
    await installStorefrontDeps(projectDir, options.packageManager)
    s.stop('Storefront dependencies installed.')
  }

  // Phase 3: Initialize and start services
  if (options.start) {
    const initArgs = ['spree', 'init']
    if (!options.sampleData) initArgs.push('--no-sample-data')

    await execa('npx', initArgs, {
      cwd: projectDir,
      stdio: 'inherit',
    })

    if (isFullStack) {
      p.log.info(
        `${pc.bold('Storefront')}: ${pc.cyan(`cd ${projectName}/apps/storefront && npm run dev`)}`,
      )
    }
  } else {
    printSuccessWithoutDocker(projectName, isFullStack, port)
  }
}

function printSuccessWithoutDocker(
  projectName: string,
  isFullStack: boolean,
  port: number,
): void {
  const lines: string[] = [
    '',
    `${pc.bold('Next steps:')}`,
    `  cd ${projectName}`,
    `  npx spree dev`,
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
    `  http://localhost:${port}/admin`,
    `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
    `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
  )

  p.note(lines.join('\n'), 'Project created!')
}
