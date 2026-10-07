import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import { execa } from 'execa'
import pc from 'picocolors'
import {
  DASHBOARD_PORT,
  DOCS_MCP_URL,
  SELLER_DASHBOARD_PORT,
  STOREFRONT_REPO,
} from './constants.js'
import { scaffoldApp } from './dashboard.js'
import { downloadServer } from './server.js'
import { installRootDeps, scaffoldStorefront } from './storefront.js'
import { agentsMdContent, rootClaudeMdContent } from './templates/claude-md.js'
import { dependabotContent } from './templates/dependabot.js'
import { envContent } from './templates/env.js'
import { dockerignoreContent, gitignoreContent } from './templates/gitignore.js'
import { rootPackageJsonContent } from './templates/package-json.js'
import { readmeContent } from './templates/readme.js'
import type { PackageManager, ScaffoldOptions } from './types.js'
import {
  dlxCommand,
  generateEncryptionKeys,
  generateSecretKeyBase,
  installCommand,
  isDockerRunning,
  runCommand,
  storefrontPm,
} from './utils.js'

export async function scaffold(options: ScaffoldOptions): Promise<void> {
  const projectDir = path.resolve(options.directory)
  const projectName = path.basename(projectDir)
  const { port, storefront, dashboard, sellerDashboard } = options

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

  // Phase 1: Download server (always included)
  s.start('Downloading server template...')
  await downloadServer(projectDir)
  s.stop('Server template downloaded.')

  // Phase 2: Generate project files
  s.start('Creating project structure...')

  // Copy compose files from server template and adjust paths for project root
  const serverDir = path.join(projectDir, 'server')
  const compose = fs.readFileSync(path.join(serverDir, 'docker-compose.yml'), 'utf-8')
  const composeDev = fs.readFileSync(path.join(serverDir, 'docker-compose.dev.yml'), 'utf-8')

  fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), compose)
  // Adjust build context and source bind-mount from current dir to ./server
  // for the wrapper project (in the starter repo the compose file lives in
  // the Rails app root; here the app lives under server/)
  fs.writeFileSync(
    path.join(projectDir, 'docker-compose.dev.yml'),
    composeDev
      .replace('context: .', 'context: ./server')
      .replace('- .:/rails', '- ./server:/rails'),
  )

  // The compose files now live (adjusted) at the wrapper root referencing
  // ./server + the root .env. The originals cloned into server/ are stale
  // leftovers (mount .:/rails, expect a sibling .env) — remove them so the CLI
  // never accidentally targets them when run from server/.
  fs.rmSync(path.join(serverDir, 'docker-compose.yml'), { force: true })
  fs.rmSync(path.join(serverDir, 'docker-compose.dev.yml'), { force: true })

  fs.writeFileSync(
    path.join(projectDir, '.env'),
    envContent(
      generateSecretKeyBase(),
      port,
      options.mailpitSmtpPort,
      options.mailpitUiPort,
      generateEncryptionKeys(),
    ),
    // Holds SECRET_KEY_BASE and the encryption keys — owner-only.
    { mode: 0o600 },
  )
  fs.writeFileSync(
    path.join(projectDir, 'package.json'),
    rootPackageJsonContent(projectName, options.packageManager),
  )
  fs.writeFileSync(path.join(projectDir, '.gitignore'), gitignoreContent())
  fs.writeFileSync(path.join(projectDir, '.dockerignore'), dockerignoreContent())
  fs.writeFileSync(path.join(projectDir, 'AGENTS.md'), agentsMdContent())

  s.stop('Project structure created.')

  // Install root dependencies (@spree/cli)
  s.start('Installing dependencies...')
  await installRootDeps(projectDir, options.packageManager)
  s.stop('Dependencies installed.')

  // Phase 3: the apps — Dashboard, Seller Panel, then storefront. Their
  // failures warn and continue: they must never abort the scaffold before
  // Phase 4, since `spree init` is what guarantees a fresh Spree image
  // (skipping it leaves a stale local `latest` to boot) and a seeded,
  // credentialed server. A failed app's partial directory is removed so the
  // recovery command, which expects it absent, actually works.
  const run = runCommand(options.packageManager)
  const tryApp = async (dir: string, recovery: string, step: () => Promise<void>) => {
    try {
      await step()
      return true
    } catch (err) {
      fs.rmSync(path.join(projectDir, 'apps', dir), { recursive: true, force: true })
      p.log.warn(
        `Continuing without apps/${dir}/ — add it later with ${pc.bold(recovery)}.\n${errorMessage(err)}`,
      )
      return false
    }
  }
  const appOpts = { install: true, packageManager: options.packageManager }

  const dashboardReady =
    dashboard &&
    (await tryApp('dashboard', `${run} spree add dashboard`, () =>
      scaffoldApp(projectDir, 'dashboard', appOpts),
    ))
  const sellerDashboardReady =
    sellerDashboard &&
    (await tryApp('seller-dashboard', `${run} spree add seller-dashboard`, () =>
      scaffoldApp(projectDir, 'seller-dashboard', appOpts),
    ))
  const storefrontReady =
    storefront &&
    (await tryApp('storefront', `git clone ${STOREFRONT_REPO} apps/storefront`, () =>
      scaffoldStorefront(projectDir, port, options.packageManager),
    ))

  // Project docs are generated only now, from the phases' actual outcomes —
  // a README written up front from the requested flags would document apps
  // whose setup failed.
  fs.writeFileSync(
    path.join(projectDir, 'README.md'),
    readmeContent(
      projectName,
      storefrontReady,
      port,
      dashboardReady,
      options.packageManager,
      sellerDashboardReady,
    ),
  )
  fs.writeFileSync(
    path.join(projectDir, 'CLAUDE.md'),
    rootClaudeMdContent(
      storefrontReady,
      dashboardReady,
      options.packageManager,
      sellerDashboardReady,
    ),
  )
  const githubDir = path.join(projectDir, '.github')
  fs.mkdirSync(githubDir, { recursive: true })
  fs.writeFileSync(
    path.join(githubDir, 'dependabot.yml'),
    dependabotContent(storefrontReady, dashboardReady, sellerDashboardReady),
  )

  // Phase 4: Initialize and start services
  if (options.start) {
    // Sample data is never part of a scaffold: first-run setup configures the
    // store through the dashboard, and the sample-data import needs an admin
    // that setup has not created yet — loading it here failed the whole init.
    // The CLI still offers it on demand via `spree sample-data`.
    const initArgs = ['spree', 'init', '--no-sample-data']

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
        `${pc.bold('Storefront')}: ${pc.cyan(`cd ${projectName}/apps/storefront && ${storefrontPm(options.packageManager)} run dev`)}`,
      )
    }
    if (sellerDashboardReady) {
      p.log.info(
        `${pc.bold('Seller Panel')}: ${pc.cyan(`cd ${projectName}/apps/seller-dashboard && ${options.packageManager} run dev`)} ${pc.dim(`→ http://localhost:${SELLER_DASHBOARD_PORT}`)}`,
      )
    }
    // No dashboard line here — with the dashboard chosen, `spree init`'s
    // summary already leads with it (served at /dashboard, plus the
    // customize command).
  } else {
    printSuccessWithoutDocker(
      projectName,
      port,
      storefrontReady,
      dashboardReady,
      sellerDashboardReady,
      options.packageManager,
    )
  }
}

function printSuccessWithoutDocker(
  projectName: string,
  port: number,
  hasStorefront: boolean,
  hasDashboard: boolean,
  hasSellerDashboard: boolean,
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

  // With apps/dashboard, its dev server is the admin — `spree dev` co-runs it
  // with the API, so the URL is live the moment the stack is up. Without it
  // the API serves the built-in dashboard at /dashboard.
  if (hasDashboard) {
    lines.push(
      '',
      `${pc.bold('Admin Dashboard')}`,
      `  http://localhost:${DASHBOARD_PORT}`,
      `  ${pc.dim('# started automatically by `spree dev`, live-reloading from apps/dashboard/')}`,
      `  ${pc.dim("# you'll create the admin account on first run")}`,
      '',
    )
  } else {
    lines.push(
      '',
      `${pc.bold('Admin Dashboard')}`,
      `  http://localhost:${port}/dashboard`,
      `  ${pc.dim(`# to customize it: ${run} spree add dashboard`)}`,
      '',
    )
  }

  if (hasSellerDashboard) {
    lines.push(
      `${pc.bold('Seller Panel')}`,
      `  ${pc.dim('# In another terminal:')}`,
      `  cd ${projectName}/apps/seller-dashboard`,
      `  ${pm} run dev`,
      `  http://localhost:${SELLER_DASHBOARD_PORT}`,
      `  ${pc.dim('# sellers you invite from the Admin Dashboard sign in here')}`,
      '',
    )
  }

  lines.push(
    `${pc.bold('Customize the Spree API')}`,
    `  ${run} spree eject`,
    `  ${pc.dim('# Then edit server/ — the Rails API app (Gemfile, app/, config/)')}`,
    '',
    `${pc.bold('Agent skills (optional)')}`,
    `  ${dlxCommand(pm)} skills add spree/agent-skills`,
    `  ${pc.dim('# Adds 23 Spree skills to whichever AI agent(s) you use')}`,
    `  ${pc.dim('# (Claude Code, Codex, Cursor, Copilot, Cline, Aider, +60 others)')}`,
    '',
    `${pc.bold('Spree docs MCP server (optional)')}`,
    `  claude mcp add --transport http spree-docs ${DOCS_MCP_URL}`,
    `  ${pc.dim('# Lets your AI agent search the latest Spree docs. Other agents:')}`,
    `  ${pc.dim('# https://spreecommerce.org/docs/developer/agentic/mcp')}`,
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
