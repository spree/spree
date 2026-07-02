import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import { execa } from 'execa'
import pc from 'picocolors'
import { downloadBackend } from './backend.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from './constants.js'
import {
  downloadStorefront,
  installRootDeps,
  installStorefrontDeps,
  writeStorefrontEnv,
} from './storefront.js'
import { agentsMdContent, rootClaudeMdContent } from './templates/claude-md.js'
import { dependabotContent } from './templates/dependabot.js'
import { envContent } from './templates/env.js'
import { gitignoreContent } from './templates/gitignore.js'
import { rootPackageJsonContent } from './templates/package-json.js'
import { readmeContent } from './templates/readme.js'
import type { ScaffoldOptions } from './types.js'
import { generateSecretKeyBase, isDockerRunning } from './utils.js'

export async function scaffold(options: ScaffoldOptions): Promise<void> {
  const projectDir = path.resolve(options.directory)
  const projectName = path.basename(projectDir)
  const { port, dbPort, meilisearchPort, storefront } = options

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

  const s = p.spinner()

  fs.mkdirSync(projectDir, { recursive: true })

  // Phase 1: Download backend (always included)
  s.start('Downloading backend template...')
  await downloadBackend(projectDir)
  s.stop('Backend template downloaded.')

  // Phase 2: Generate project files
  s.start('Creating project structure...')

  // Copy compose files from backend template and adjust paths for project root
  const backendDir = path.join(projectDir, 'backend')
  const compose = fs.readFileSync(path.join(backendDir, 'docker-compose.yml'), 'utf-8')
  const composeDev = fs.readFileSync(path.join(backendDir, 'docker-compose.dev.yml'), 'utf-8')

  fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), compose)
  // Adjust build context and source bind-mount from current dir to ./backend
  // for the wrapper project (in the starter repo the compose file lives in
  // the Rails app root; here the app lives under backend/)
  fs.writeFileSync(
    path.join(projectDir, 'docker-compose.dev.yml'),
    composeDev
      .replace('context: .', 'context: ./backend')
      .replace('- .:/rails', '- ./backend:/rails'),
  )

  // The compose files now live (adjusted) at the wrapper root referencing
  // ./backend + the root .env. The originals cloned into backend/ are stale
  // leftovers (mount .:/rails, expect a sibling .env) — remove them so the CLI
  // never accidentally targets them when run from backend/.
  fs.rmSync(path.join(backendDir, 'docker-compose.yml'), { force: true })
  fs.rmSync(path.join(backendDir, 'docker-compose.dev.yml'), { force: true })

  fs.writeFileSync(
    path.join(projectDir, '.env'),
    envContent(generateSecretKeyBase(), { web: port, db: dbPort, meilisearch: meilisearchPort }),
  )
  fs.writeFileSync(path.join(projectDir, 'package.json'), rootPackageJsonContent(projectName))
  fs.writeFileSync(path.join(projectDir, 'README.md'), readmeContent(projectName, storefront, port))
  fs.writeFileSync(path.join(projectDir, '.gitignore'), gitignoreContent())
  fs.writeFileSync(path.join(projectDir, 'CLAUDE.md'), rootClaudeMdContent(storefront))
  fs.writeFileSync(path.join(projectDir, 'AGENTS.md'), agentsMdContent())

  const githubDir = path.join(projectDir, '.github')
  fs.mkdirSync(githubDir, { recursive: true })
  fs.writeFileSync(path.join(githubDir, 'dependabot.yml'), dependabotContent(storefront))

  s.stop('Project structure created.')

  // Install root dependencies (@spree/cli)
  s.start('Installing dependencies...')
  await installRootDeps(projectDir, options.packageManager)
  s.stop('Dependencies installed.')

  // Phase 3: Storefront (optional)
  if (storefront) {
    s.start('Downloading storefront template...')
    await downloadStorefront(projectDir)
    s.stop('Storefront template downloaded.')

    writeStorefrontEnv(projectDir, port)

    s.start('Installing storefront dependencies...')
    await installStorefrontDeps(projectDir, options.packageManager)
    s.stop('Storefront dependencies installed.')
  }

  // Phase 4: Initialize and start services
  if (options.start) {
    const initArgs = ['spree', 'init']
    if (!options.sampleData) initArgs.push('--no-sample-data')

    await execa('npx', initArgs, {
      cwd: projectDir,
      stdio: 'inherit',
    })

    if (storefront) {
      p.log.info(
        `${pc.bold('Storefront')}: ${pc.cyan(`cd ${projectName}/apps/storefront && npm run dev`)}`,
      )
    }
  } else {
    printSuccessWithoutDocker(projectName, storefront, port)
  }
}

function printSuccessWithoutDocker(
  projectName: string,
  hasStorefront: boolean,
  port: number,
): void {
  const lines: string[] = [
    '',
    `${pc.bold('Next steps:')}`,
    `  cd ${projectName}`,
    `  npx spree dev`,
  ]

  if (hasStorefront) {
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
    '',
    `${pc.bold('Customize the backend')}`,
    `  npx spree eject`,
    `  ${pc.dim('# Then edit backend/Gemfile, backend/app/, backend/config/')}`,
    '',
    `${pc.bold('Agent skills (optional)')}`,
    `  npx skills add spree/agent-skills`,
    `  ${pc.dim('# Adds 23 Spree skills to whichever AI agent(s) you use')}`,
    `  ${pc.dim('# (Claude Code, Codex, Cursor, Copilot, Cline, Aider, +60 others)')}`,
    '',
    `${pc.bold('Join our Discord')}`,
    `  https://discord.spreecommerce.org`,
    '',
    `${pc.bold('Learn more')}`,
    `  https://spreecommerce.org/docs`,
  )

  p.note(lines.join('\n'), 'Project created!')
}
