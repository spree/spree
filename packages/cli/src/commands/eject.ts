import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, findApiDir } from '../context.js'
import { dockerCompose, dockerComposeExec, primeBundleVolume } from '../docker.js'

// Switch the project from the prebuilt-image compose to the bind-mounted
// dev compose. Source under the API directory becomes live in the container —
// edits reload via Zeitwerk on next request, no rebuild needed.
//
// Image rebuilds (`spree build`) are only required for Dockerfile or
// .ruby-version changes; gem changes go through `spree bundle add` and
// persist in the bundle_cache volume.
export function registerEjectCommand(program: Command) {
  program
    .command('eject')
    .description('Switch to the dev compose: bind-mount the Rails app with hot reload')
    .action(async () => {
      const ctx = detectProject()

      const apiDir = findApiDir(ctx.projectDir)
      const apiPath = path.join(ctx.projectDir, apiDir)
      if (!fs.existsSync(apiPath)) {
        console.error(`\n${pc.red('Error:')} No ${apiDir}/ directory found.\n`)
        process.exit(1)
      }

      const devCompose = path.join(ctx.projectDir, 'docker-compose.dev.yml')
      if (!fs.existsSync(devCompose)) {
        console.error(`\n${pc.red('Error:')} No docker-compose.dev.yml found.\n`)
        process.exit(1)
      }

      // Replace docker-compose.yml with the dev version. The dev compose has
      // `build:` defined, so `up -d` below will build on first invocation —
      // no separate explicit build step needed.
      //
      // Projects scaffolded before create-spree-app 1.0.3 shipped a dev
      // compose that bind-mounts the project root (`.:/rails`) instead of
      // the API directory — rewrite it so the container finds bin/rails.
      let composeContent = fs.readFileSync(devCompose, 'utf-8')
      if (composeContent.includes('- .:/rails')) {
        composeContent = composeContent.replace('- .:/rails', `- ./${apiDir}:/rails`)
        fs.writeFileSync(devCompose, composeContent)
      }
      fs.writeFileSync(path.join(ctx.projectDir, 'docker-compose.yml'), composeContent)

      console.log(`\n${pc.bold(`Switching to dev compose (bind-mounts ./${apiDir})...`)}\n`)
      // Prime the shared bundle_cache volume with web alone so the parallel up
      // below doesn't race the cold-volume copy-up (web + worker → "file exists").
      await primeBundleVolume(ctx.projectDir)
      await dockerCompose(['up', '-d'], ctx.projectDir, { stdio: 'inherit' })

      // The dev image bypasses bin/docker-entrypoint (which runs db:prepare
      // in the prebuilt image), and the dev environment uses its own
      // spree_development database — make sure it exists and is migrated.
      console.log(`\n${pc.bold('Preparing the development database...')}\n`)
      await dockerComposeExec(['bin/rails', 'db:prepare'], ctx.projectDir, { tty: false })

      p.note(
        [
          `The Rails API is now bind-mounted from ${pc.bold(`./${apiDir}`)} — edits are live.`,
          '',
          `The dev stack uses its own ${pc.bold('spree_development')} database (just`,
          `created and seeded). Load demo products with ${pc.bold('spree sample-data')}.`,
          '',
          'You can now customize:',
          `  ${pc.dim(`${apiDir}/app/`)}             — models, controllers, services (instant reload)`,
          `  ${pc.dim(`${apiDir}/config/`)}          — Rails configuration (instant reload)`,
          `  ${pc.dim(`${apiDir}/Gemfile`)}          — add gems via ${pc.bold('spree bundle add <gem>')}`,
          '',
          `Rebuild only on Dockerfile / .ruby-version changes: ${pc.bold('spree build')}`,
        ].join('\n'),
        'Ejected!',
      )
    })
}
