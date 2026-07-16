import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import { execa } from 'execa'
import pc from 'picocolors'
import { downloadBackend } from './backend.js'
import {
  DASHBOARD_PORT,
  DEFAULT_ADMIN_EMAIL,
  DEFAULT_ADMIN_PASSWORD,
  STOREFRONT_REPO,
} from './constants.js'
import { scaffoldDashboard } from './dashboard.js'
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
import type { PackageManager, ScaffoldOptions } from './types.js'
import {
  dlxCommand,
  generateSecretKeyBase,
  installCommand,
  isDockerRunning,
  runCommand,
} from './utils.js'

export async function scaffold(options: ScaffoldOptions): Promise<void> {
  const projectDir = path.resolve(options.directory)
  const projectName = path.basename(projectDir)
  const { port, storefront, dashboard } = options

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
    envContent(generateSecretKeyBase(), port, options.sampleData),
  )
  fs.writeFileSync(path.join(projectDir, 'package.json'), rootPackageJsonContent(projectName))
  fs.writeFileSync(path.join(projectDir, '.gitignore'), gitignoreContent())
  fs.writeFileSync(path.join(projectDir, 'AGENTS.md'), agentsMdContent())

  s.stop('Project structure created.')

  // Install root dependencies (@spree/cli)
  s.start('Installing dependencies...')
  await installRootDeps(projectDir, options.packageManager)
  s.stop('Dependencies installed.')

  // Phases 3/3b are optional apps — their failures warn and continue. They
  // must never abort the scaffold before Phase 4: `spree init` is what
  // guarantees a fresh Spree image (skipping it leaves a stale local `latest`
  // to boot) and a seeded, credentialed backend.

  // Phase 3: Storefront (optional)
  let storefrontReady = storefront
  if (storefront) {
    try {
      s.start('Downloading storefront template...')
      await downloadStorefront(projectDir)
      s.stop('Storefront template downloaded.')

      writeStorefrontEnv(projectDir, port)

      s.start('Installing storefront dependencies...')
      await installStorefrontDeps(projectDir, options.packageManager)
      s.stop('Storefront dependencies installed.')
    } catch (err) {
      storefrontReady = false
      s.stop('Storefront setup failed.')
      // Remove the partial checkout so the recovery command (a fresh clone)
      // actually works instead of failing on a non-empty directory.
      fs.rmSync(path.join(projectDir, 'apps', 'storefront'), { recursive: true, force: true })
      p.log.warn(
        `Continuing without the storefront — add it later by cloning ${STOREFRONT_REPO} into apps/storefront.\n${errorMessage(err)}`,
      )
    }
  }

  // Phase 3b: React Dashboard (optional, Developer Preview). Delegates to the
  // project-local `npx spree add dashboard` — @spree/cli is already installed
  // (root deps, above) and bundles the dashboard-starter template. It reads
  // the port from the project's .env and prints its own progress.
  let dashboardReady = dashboard
  if (dashboard) {
    try {
      await scaffoldDashboard(projectDir, { install: true, packageManager: options.packageManager })
    } catch (err) {
      dashboardReady = false
      // Remove the partial scaffold so the recovery command (`spree add
      // dashboard`, which expects the directory to be absent) actually works.
      fs.rmSync(path.join(projectDir, 'apps', 'dashboard'), { recursive: true, force: true })
      p.log.warn(
        `Continuing without the React Dashboard — add it later with ${pc.bold(`${runCommand(options.packageManager)} spree add dashboard`)}.\n${errorMessage(err)}`,
      )
    }
  }

  // Project docs are generated only now, from the phases' actual outcomes —
  // a README written up front from the requested flags would document apps
  // whose setup failed.
  fs.writeFileSync(
    path.join(projectDir, 'README.md'),
    readmeContent(projectName, storefrontReady, port, dashboardReady, options.packageManager),
  )
  fs.writeFileSync(
    path.join(projectDir, 'CLAUDE.md'),
    rootClaudeMdContent(storefrontReady, dashboardReady, options.packageManager),
  )
  const githubDir = path.join(projectDir, '.github')
  fs.mkdirSync(githubDir, { recursive: true })
  fs.writeFileSync(
    path.join(githubDir, 'dependabot.yml'),
    dependabotContent(storefrontReady, dashboardReady),
  )

  // Phase 4: Initialize and start services
  if (options.start) {
    const initArgs = ['spree', 'init']
    if (!options.sampleData) initArgs.push('--no-sample-data')

    try {
      await execa(runCommand(options.packageManager), initArgs, {
        cwd: projectDir,
        stdio: 'inherit',
      })
    } catch {
      // init streams its own output, so the underlying failure is already on
      // screen — what the operator needs from us is the recovery command.
      throw new Error(
        `Setup did not finish. Start your app with: cd ${projectName} && ${options.packageManager} run dev — the first run completes setup automatically.`,
      )
    }

    if (storefrontReady) {
      p.log.info(
        `${pc.bold('Storefront')}: ${pc.cyan(`cd ${projectName}/apps/storefront && ${options.packageManager} run dev`)}`,
      )
    }
    // No dashboard line here — with the dashboard chosen, `spree init`'s
    // summary already leads with it (served at /dashboard, plus the
    // customize command).
  } else {
    printSuccessWithoutDocker(
      projectName,
      storefrontReady,
      dashboardReady,
      port,
      options.packageManager,
    )
  }
}

function printSuccessWithoutDocker(
  projectName: string,
  hasStorefront: boolean,
  hasDashboard: boolean,
  port: number,
  pm: PackageManager,
): void {
  const run = runCommand(pm)
  const lines: string[] = [
    '',
    `${pc.bold('Next steps:')}`,
    `  cd ${projectName}`,
    `  ${run} spree dev`,
    `  ${pc.dim('# First run completes setup automatically — pulls the latest image, seeds data, configures API keys.')}`,
  ]

  if (hasStorefront) {
    lines.push(
      '',
      `  ${pc.dim('# In another terminal:')}`,
      `  cd ${projectName}/apps/storefront`,
      `  ${installCommand(pm)}`,
      `  ${pm} run dev`,
    )
  }

  // With the React Dashboard chosen, its dev server IS the admin — what the
  // user customizes is what they use. One admin block; the classic admin
  // gets a one-line pointer.
  if (hasDashboard) {
    lines.push(
      '',
      `${pc.bold('Admin Dashboard (React, Developer Preview)')}`,
      `  cd ${projectName}/apps/dashboard && ${pm} run dev`,
      `  → http://localhost:${DASHBOARD_PORT}`,
      `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
      `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
      `  ${pc.dim(`Classic admin: http://localhost:${port}/admin`)}`,
      '',
    )
  } else {
    lines.push(
      '',
      `${pc.bold('Admin Dashboard')}`,
      `  http://localhost:${port}/admin`,
      `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
      `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
      '',
    )
  }

  lines.push(
    `${pc.bold('Customize the backend')}`,
    `  ${run} spree eject`,
    `  ${pc.dim('# Then edit backend/Gemfile, backend/app/, backend/config/')}`,
    '',
    `${pc.bold('Agent skills (optional)')}`,
    `  ${dlxCommand(pm)} skills add spree/agent-skills`,
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

function errorMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err)
}
