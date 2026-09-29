import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, findApiDir } from '../context.js'
import { dockerCompose, prepareDatabase } from '../docker.js'

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

      // Replace docker-compose.yml with the dev version.
      //
      // Projects scaffolded before create-spree-app 1.0.3 shipped a dev
      // compose that bind-mounts the project root (`.:/rails`) instead of
      // the API directory — rewrite it so the container finds bin/rails.
      let composeContent = fs.readFileSync(devCompose, 'utf-8')
      if (composeContent.includes('- .:/rails')) {
        composeContent = composeContent.replace('- .:/rails', `- ./${apiDir}:/rails`)
        fs.writeFileSync(devCompose, composeContent)
      }
      // Older dev composes check postgres over the unix socket, which the
      // image's temporary init server also answers on a brand-new volume —
      // so dependants started against a server that was about to restart.
      // Only the real server listens on TCP.
      if (composeContent.includes('test: pg_isready -U postgres')) {
        composeContent = composeContent.replace(
          'test: pg_isready -U postgres',
          'test: pg_isready -h 127.0.0.1 -U postgres',
        )
        fs.writeFileSync(devCompose, composeContent)
      }
      fs.writeFileSync(path.join(ctx.projectDir, 'docker-compose.yml'), composeContent)

      console.log(`\n${pc.bold(`Switching to dev compose (bind-mounts ./${apiDir})...`)}\n`)

      // The dev environment uses its own spree_development database, and the
      // app server exits when it is missing — create and migrate it first.
      // The dev compose has `build:` defined, so this first `run` also builds
      // the image — no separate explicit build step needed.
      console.log(`${pc.bold('Preparing the development database...')}\n`)
      await prepareDatabase(ctx.projectDir, { stdio: 'inherit' })

      await dockerCompose(['up', '-d'], ctx.projectDir, { stdio: 'inherit' })

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
