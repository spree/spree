import type { Command } from 'commander'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { railsRunner } from '../docker.js'

export function registerApiKeyCommand(program: Command): void {
  const apiKey = program
    .command('api-key')
    .description('Manage API keys')

  apiKey
    .command('create')
    .description('Create an API key')
    .option('--name <name>', 'key name')
    .option('--type <type>', 'key type: publishable or secret')
    .action(async (flags: { name?: string; type?: string }) => {
      const ctx = detectProject()

      let name = flags.name
      let keyType = flags.type

      if (!name) {
        const result = await p.text({
          message: 'Key name:',
          placeholder: 'My Storefront',
          validate(value) {
            if (!value) return 'Name is required'
            return undefined
          },
        })
        if (p.isCancel(result)) {
          p.cancel('Cancelled.')
          process.exit(0)
        }
        name = result
      }

      if (!keyType) {
        const result = await p.select({
          message: 'Key type:',
          options: [
            { value: 'publishable', label: 'Publishable (for storefronts)' },
            { value: 'secret', label: 'Secret (for server-to-server)' },
          ],
        })
        if (p.isCancel(result)) {
          p.cancel('Cancelled.')
          process.exit(0)
        }
        keyType = result as string
      }

      if (keyType !== 'publishable' && keyType !== 'secret') {
        throw new Error('Key type must be "publishable" or "secret".')
      }

      const s = p.spinner()
      s.start('Creating API key...')

      const safeName = name.replace(/'/g, "\\'")
      const script = [
        `key = Spree::Store.default.api_keys.create!(`,
        `name: '${safeName}',`,
        `key_type: '${keyType}'`,
        `);`,
        `print key.plaintext_token`,
      ].join(' ')

      const stdout = await railsRunner(script, ctx.projectDir)

      const tokenPrefix = keyType === 'publishable' ? 'pk_' : 'sk_'
      const match = stdout.match(new RegExp(`${tokenPrefix}[A-Za-z0-9_-]+`))
      const token = match ? match[0] : stdout.trim()

      s.stop('API key created.')

      const lines = [
        `${pc.bold('Name:')}  ${name}`,
        `${pc.bold('Type:')}  ${keyType}`,
        `${pc.bold('Token:')} ${pc.cyan(token)}`,
      ]

      if (keyType === 'secret') {
        lines.push('')
        lines.push(pc.yellow('Save this token now — secret keys cannot be retrieved later.'))
      }

      p.note(lines.join('\n'), 'API Key')
    })

  apiKey
    .command('list')
    .description('List API keys')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Fetching API keys...')

      const script = [
        `Spree::Store.default.api_keys.order(created_at: :desc).each { |k|`,
        `status = k.revoked_at ? 'revoked' : 'active';`,
        `prefix = k.secret? ? k.token_prefix : k.token;`,
        `puts [k.name, k.key_type, prefix, k.created_at.strftime('%Y-%m-%d %H:%M'), status].join('|')`,
        `}`,
      ].join(' ')

      const stdout = await railsRunner(script, ctx.projectDir)
      s.stop('')

      const lines = stdout.trim().split('\n').filter(Boolean)

      if (lines.length === 0) {
        p.log.info('No API keys found.')
        return
      }

      console.log('')
      console.log(
        `  ${pc.bold('Name'.padEnd(25))} ${pc.bold('Type'.padEnd(14))} ${pc.bold('Token'.padEnd(30))} ${pc.bold('Created'.padEnd(18))} ${pc.bold('Status')}`,
      )
      console.log(`  ${'─'.repeat(95)}`)

      for (const line of lines) {
        const [name, type, prefix, created, status] = line.split('|')
        const statusText = status === 'active' ? pc.green(status!) : pc.red(status!)
        console.log(
          `  ${(name ?? '').padEnd(25)} ${(type ?? '').padEnd(14)} ${(prefix ?? '').padEnd(30)} ${(created ?? '').padEnd(18)} ${statusText}`,
        )
      }
      console.log('')
    })

  apiKey
    .command('revoke')
    .description('Revoke an API key')
    .argument('<token>', 'token or token prefix of the key to revoke')
    .action(async (token: string) => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Revoking API key...')

      const safeToken = token.replace(/'/g, "\\'")

      // Try finding by token (publishable) or token_prefix (secret)
      const script = [
        `key = Spree::Store.default.api_keys.find_by(token: '${safeToken}') ||`,
        `Spree::Store.default.api_keys.find_by!(token_prefix: '${safeToken}');`,
        `key.revoke!;`,
        `print key.name`,
      ].join(' ')

      const stdout = await railsRunner(script, ctx.projectDir)
      const name = stdout.trim()

      s.stop(`API key "${name}" revoked.`)
    })
}
