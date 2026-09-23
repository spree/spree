import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, findApiDir, isEjectedProject } from '../context.js'
import {
  APPLICATION_RB_SNIPPET,
  appReadsEncryptionEnv,
  configuredEncryptionVars,
  formatEncryptionEnv,
  generateEncryptionKeys,
  withEncryptionKeys,
} from '../lib/encryption.js'

const DOCS_URL =
  'https://spreecommerce.org/docs/developer/deployment/environment_variables#active-record-encryption'

export function registerEncryptionCommand(program: Command): void {
  const encryption = program
    .command('encryption')
    .description('Manage Active Record encryption keys')

  encryption
    .command('init')
    .description(
      'Generate Active Record encryption keys and add them to .env (never overwrites existing keys)',
    )
    .option('--print', 'only print a fresh set of keys (e.g. for your hosting provider)')
    .addHelpText(
      'after',
      '\nSpree encrypts webhook signing keys, payment gateway customer ids and OAuth tokens\n' +
        'at rest only when these keys are set. Once data is encrypted, never change them —\n' +
        'encrypted rows become unreadable. There is deliberately no --force.',
    )
    .action((flags: { print?: boolean }) => {
      if (flags.print) {
        process.stdout.write(`${formatEncryptionEnv(generateEncryptionKeys())}\n`)
        return
      }

      initEncryption(detectProject().projectDir)
    })
}

export function initEncryption(projectDir: string): void {
  const envPath = path.join(projectDir, '.env')
  const content = fs.existsSync(envPath) ? fs.readFileSync(envPath, 'utf-8') : ''
  const configured = configuredEncryptionVars(content)

  if (configured.length > 0) {
    p.log.warn(
      `.env already sets ${configured.join(', ')} — leaving it unchanged.\n` +
        'Changing encryption keys makes data encrypted with them unreadable.' +
        (configured.length < 3
          ? '\nAdd the missing values by hand (`spree encryption init --print`).'
          : ''),
    )
    return
  }

  fs.writeFileSync(envPath, withEncryptionKeys(content, generateEncryptionKeys()))
  p.log.success('Added Active Record encryption keys to .env.')

  const apiDir = findApiDir(projectDir)
  const ejected = isEjectedProject(projectDir)
  if (ejected && !appReadsEncryptionEnv(path.join(projectDir, apiDir))) {
    p.log.warn(
      `${apiDir}/config doesn't read these env vars yet. Add this inside the Application class in ${apiDir}/config/application.rb:\n\n` +
        pc.dim(APPLICATION_RB_SNIPPET),
    )
  }

  p.note(
    [
      `1. Recreate the containers to load the new .env: ${pc.cyan(ejected ? 'spree dev' : 'spree update')}`,
      `   (${pc.cyan('spree restart')} keeps the old environment).`,
      '2. Back up the three values in your secret manager —',
      '   losing them makes encrypted data unreadable.',
      '3. Production: set the three env vars on your host before deploying',
      `   (a separate set: ${pc.cyan('spree encryption init --print')}) and never change them.`,
      '',
      DOCS_URL,
    ].join('\n'),
    'Next steps',
  )
}
