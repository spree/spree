import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import { spreeTask } from '../backend.js'
import { detectProject } from '../context.js'
import { captureTask } from '../docker.js'
import { VERSION } from '../version.js'
import { APP_DIRS, detectPackageManager } from './add.js'
import { openBrowser } from './init.js'
import { detectSpreePackages } from './upgrade.js'

interface ServerReport {
  markdown: string
  issue_url: string
  issue_prefilled: boolean
  [key: string]: unknown
}

export function registerInfoCommand(program: Command): void {
  program
    .command('info')
    .description('Print an anonymised diagnostics report to attach to a bug report')
    .option('--json', 'print the report as JSON')
    .option('--issue', 'open a GitHub issue with the report filled in')
    .action(async (options: { json?: boolean; issue?: boolean }) => {
      const ctx = detectProject()
      const report = await serverReport(ctx.projectDir)
      if (!report) {
        p.log.error(
          'The server printed no diagnostics report. `spree info` needs Spree 6.0.4 or newer on the server.',
        )
        process.exitCode = 1
        return
      }

      if (options.json) {
        console.log(JSON.stringify(report, null, 2))
        return
      }

      console.log(report.markdown)
      if (!options.issue) return

      if (!report.issue_prefilled) {
        p.log.warn('The report is too long to pre-fill. Paste the output above into the issue.')
      }
      await openBrowser(report.issue_url)
    })
}

// A server without the task fails the command rather than printing nothing,
// so a failure ends in the same version hint, after what the server said.
async function serverReport(projectDir: string): Promise<ServerReport | null> {
  try {
    // The server renders the CLI's section with its own, so the report
    // reads the same wherever it came from.
    const output = await captureTask(spreeTask('info'), projectDir, {
      FORMAT: 'json',
      SPREE_INFO_CLIENT: JSON.stringify({ title: 'CLI', rows: await clientRows(projectDir) }),
    })
    // Boot can print other lines first; the report is the one JSON line.
    const line = output
      .split('\n')
      .reverse()
      .find((candidate) => candidate.startsWith('{'))
    return line ? (JSON.parse(line) as ServerReport) : null
  } catch (error) {
    p.log.error(error instanceof Error ? error.message : String(error))
    return null
  }
}

/** What only the CLI can see: the project's tooling and @spree/* packages. */
export async function clientRows(projectDir: string): Promise<Record<string, string>> {
  const dirs = [
    '.',
    ...APP_DIRS.map((dir) => path.join('apps', dir)),
    path.join('apps', 'storefront'),
  ]
  const packages: Record<string, string> = {}
  for (const relative of dirs) {
    const dir = path.join(projectDir, relative)
    for (const { name, spec } of detectSpreePackages(dir)) {
      packages[name] ??= installedVersion(dir, name) ?? spec
    }
  }

  // The running CLI, not the project's copy, which `npx` may bypass.
  delete packages['@spree/cli']

  return {
    '@spree/cli': VERSION,
    Node: process.version,
    'Package manager': detectPackageManager(projectDir, projectDir),
    'Operating system': `${os.type()} ${os.release()} ${os.arch()}`,
    Docker: (await dockerVersion()) ?? 'not found',
    ...Object.fromEntries(Object.entries(packages).sort(([a], [b]) => a.localeCompare(b))),
  }
}

function installedVersion(dir: string, name: string): string | undefined {
  try {
    const manifest = path.join(dir, 'node_modules', name, 'package.json')
    return (JSON.parse(fs.readFileSync(manifest, 'utf-8')) as { version: string }).version
  } catch {
    return undefined
  }
}

async function dockerVersion(): Promise<string | null> {
  try {
    const { stdout } = await execa('docker', ['version', '--format', '{{.Server.Version}}'])
    return stdout.trim() || null
  } catch {
    return null
  }
}
