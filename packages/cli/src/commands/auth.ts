import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { printTable } from 'console-table-printer'
import pc from 'picocolors'
import { handleApiError } from '../api/output.js'
import { formatPingStatus, pingCredentials } from '../api/ping.js'
import {
  configPath,
  projectCredentialsPath,
  readConfig,
  resolveCredentials,
  tokenPrefix,
  writeConfig,
} from '../config.js'
import { detectProject } from '../context.js'

export function registerAuthCommand(program: Command): void {
  const auth = program
    .command('auth')
    .description('Manage Admin API credentials (profiles in ~/.config/spree)')

  auth
    .command('login')
    .description('Save a secret API key as a named profile')
    .option('--profile <name>', 'profile name', 'default')
    .option('--base-url <url>', 'store URL, e.g. https://store.example.com')
    .action(async (flags: { profile: string; baseUrl?: string }) => {
      // `login` is interactive (the key is prompted, never a flag, so it can't
      // leak into shell history). In a non-TTY there's nothing to prompt —
      // fail loudly with the non-interactive alternative rather than hang or
      // exit 0 having saved nothing.
      if (!process.stdin.isTTY) {
        process.stderr.write(
          `${pc.red('error:')} \`spree auth login\` is interactive. For non-interactive use, set ` +
            'SPREE_BASE_URL + SPREE_API_KEY (or pass --base-url/--api-key to `spree api`).\n',
        )
        process.exit(2)
      }

      let baseUrl = flags.baseUrl
      if (!baseUrl) {
        const result = await p.text({
          message: 'Store URL:',
          placeholder: 'https://store.example.com',
          validate(value) {
            if (!value) return 'URL is required'
            if (!/^https?:\/\//.test(value)) return 'Must start with http:// or https://'
            return undefined
          },
        })
        if (p.isCancel(result)) {
          p.cancel('Cancelled.')
          process.exit(130)
        }
        baseUrl = result
      }
      baseUrl = baseUrl.replace(/\/$/, '')

      // The key is read from an interactive prompt, never a flag — flags leak
      // into shell history and process lists. Create the key in the admin
      // under Settings → API Keys.
      const keyResult = await p.password({
        message: 'Secret API key (sk_...):',
        validate(value) {
          if (!value) return 'Key is required'
          if (!value.startsWith('sk_')) return 'Admin API keys start with sk_'
          return undefined
        },
      })
      if (p.isCancel(keyResult)) {
        p.cancel('Cancelled.')
        process.exit(130)
      }
      const token = keyResult

      const s = p.spinner()
      s.start('Validating credentials...')
      const ping = await pingCredentials(baseUrl, token)
      if (ping.status === 'unauthorized') {
        s.stop(pc.red('The server rejected this key (401). Check the key and try again.'))
        process.exit(2)
      }
      if (ping.status === 'unreachable') {
        s.stop(pc.red(`Could not reach ${baseUrl}: ${ping.message}`))
        process.exit(2)
      }
      s.stop(
        ping.storeName
          ? `Connected to ${pc.bold(ping.storeName)}.`
          : 'Credentials accepted (key lacks read_settings, so the store name is hidden — that is fine).',
      )

      const config = readConfig()
      config.profiles[flags.profile] = { baseUrl, token }
      config.defaultProfile ||= flags.profile
      writeConfig(config)

      p.note(
        [
          `${pc.bold('Profile:')}  ${flags.profile}${config.defaultProfile === flags.profile ? pc.dim(' (default)') : ''}`,
          `${pc.bold('Base URL:')} ${baseUrl}`,
          `${pc.bold('Key:')}      ${tokenPrefix(token)}${pc.dim('…')}`,
          '',
          pc.dim(`Saved to ${configPath()}`),
        ].join('\n'),
        'Logged in',
      )
    })

  auth
    .command('status')
    .description('Show which credentials `spree api` would use, and verify them')
    .option('--profile <name>', 'check a specific profile')
    .action(async (flags: { profile?: string }) => {
      let credentials: Awaited<ReturnType<typeof resolveCredentials>>
      try {
        credentials = await resolveCredentials({ profile: flags.profile }, { allowMint: false })
      } catch (error) {
        // Maps CredentialError → exit 2 with the lowercase `error:` prefix,
        // matching the `spree api` verbs.
        handleApiError(error)
      }

      const s = p.spinner()
      s.start('Checking server...')
      const ping = await pingCredentials(credentials.baseUrl, credentials.apiKey)
      s.stop('')

      const statusLine = formatPingStatus(ping)

      p.note(
        [
          `${pc.bold('Source:')}   ${credentials.source}${credentials.profileName ? ` (${credentials.profileName})` : ''}`,
          `${pc.bold('Base URL:')} ${credentials.baseUrl}`,
          `${pc.bold('Key:')}      ${credentials.tokenPrefix}${pc.dim('…')}`,
          ...(credentials.scopes
            ? [`${pc.bold('Scopes:')}   ${credentials.scopes.join(', ')}`]
            : []),
          `${pc.bold('Server:')}   ${statusLine}`,
        ].join('\n'),
        'Auth status',
      )
    })

  auth
    .command('logout')
    .description('Remove a saved profile (or the project credentials)')
    .option('--profile <name>', 'profile to remove', 'default')
    .option('--project', 'remove .spree/credentials.json from the current project instead')
    .action(async (flags: { profile: string; project?: boolean }) => {
      if (flags.project) {
        const { projectDir } = detectProject()
        const fs = await import('node:fs')
        fs.rmSync(projectCredentialsPath(projectDir), { force: true })
        p.log.success(
          'Removed project credentials. The next `spree api` call mints a fresh read-only key.',
        )
        return
      }

      const config = readConfig()
      if (!config.profiles[flags.profile]) {
        const names = Object.keys(config.profiles)
        const available = names.length
          ? ` Saved profiles: ${names.join(', ')}.`
          : ' No profiles are saved.'
        process.stderr.write(
          `${pc.red('error:')} no profile named "${flags.profile}".${available}\n`,
        )
        process.exit(2)
      }
      delete config.profiles[flags.profile]
      if (config.defaultProfile === flags.profile) {
        config.defaultProfile = Object.keys(config.profiles)[0]
      }
      writeConfig(config)
      p.log.success(
        `Removed profile "${flags.profile}". The key itself stays active — revoke it with \`spree api-key revoke\` or in the admin.`,
      )
    })

  auth
    .command('list')
    .description('List saved profiles')
    .action(() => {
      const config = readConfig()
      const names = Object.keys(config.profiles)
      if (names.length === 0) {
        p.log.info('No profiles saved. Run `spree auth login` to add one.')
        return
      }

      printTable(
        names.map((name) => ({
          Profile: config.defaultProfile === name ? `${name} *` : name,
          'Base URL': config.profiles[name].baseUrl,
          Key: `${tokenPrefix(config.profiles[name].token)}…`,
        })),
      )
    })
}
