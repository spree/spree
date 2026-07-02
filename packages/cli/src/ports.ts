import fs from 'node:fs'
import net from 'node:net'
import path from 'node:path'
import * as p from '@clack/prompts'
import { execa } from 'execa'
import pc from 'picocolors'

// Which .env variable moves a service's host port — keeps the conflict message
// actionable for the ports the starter compose publishes. Only offered when
// the project's own compose file actually interpolates the variable: projects
// scaffolded from older starters hardcode the port, and telling their users to
// set an env var the compose never reads would send them in a circle.
const PORT_ENV_HINTS: Record<string, string> = {
  web: 'SPREE_PORT',
  postgres: 'SPREE_DB_PORT',
}

interface PublishedPort {
  service: string
  hostIp: string
  hostPort: number
}

interface PortHolder {
  container: string
  composeProject: string
}

/**
 * A published host port this project needs that something else is holding.
 */
export interface PortConflict {
  service: string
  hostPort: number
  /** The holder, or `null` when a non-Docker process on the host holds it. */
  holder: PortHolder | null
  /** The `.env` variable that moves this port, when the project's compose interpolates one. */
  envVar?: string
}

async function readComposeConfig(
  projectDir: string,
): Promise<{ name: string; ports: PublishedPort[] }> {
  const { stdout } = await execa('docker', ['compose', 'config', '--format', 'json'], {
    cwd: projectDir,
  })
  const config = JSON.parse(stdout) as {
    name?: string
    services?: Record<string, { ports?: Array<{ host_ip?: string; published?: string | number }> }>
  }

  const ports: PublishedPort[] = []
  for (const [service, definition] of Object.entries(config.services ?? {})) {
    for (const mapping of definition.ports ?? []) {
      const hostPort = Number(mapping.published)
      // Skips unpublished mappings and host-port ranges ("8000-8010"), which
      // can't be attributed to one port anyway.
      if (!Number.isInteger(hostPort) || hostPort <= 0) continue
      ports.push({ service, hostIp: mapping.host_ip ?? '0.0.0.0', hostPort })
    }
  }

  return { name: config.name ?? '', ports }
}

async function findDockerHolder(hostPort: number, hostIp: string): Promise<PortHolder | null> {
  const { stdout } = await execa('docker', [
    'ps',
    '--filter',
    `publish=${hostPort}`,
    '--format',
    '{{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Ports}}',
  ])
  for (const line of stdout.split('\n')) {
    if (line.trim() === '') continue
    const [container = '', composeProject = '', portsText = ''] = line.split('\t')
    if (!holderBindingsOverlap(portsText, hostPort, hostIp)) continue
    return { container, composeProject }
  }
  return null
}

// `docker ps --filter publish=N` matches the host port number across every
// interface — a container publishing 192.0.2.2:N cannot collide with our
// 127.0.0.1:N publish, so require the bound IPs to actually overlap before
// blaming a holder. Wildcard binds (0.0.0.0 / [::]) overlap everything.
function holderBindingsOverlap(portsText: string, hostPort: number, hostIp: string): boolean {
  const wildcard = (ip: string) => ip === '0.0.0.0' || ip === '::'
  for (const entry of portsText.split(',')) {
    const match = entry.trim().match(/^(?:\[([^\]]+)\]|([0-9.]+)):(\d+)(?:-(\d+))?->/)
    if (!match) continue
    const holderIp = match[1] ?? match[2] ?? ''
    const low = Number(match[3])
    const high = match[4] ? Number(match[4]) : low
    if (hostPort < low || hostPort > high) continue
    if (wildcard(hostIp) || wildcard(holderIp) || holderIp === hostIp) return true
  }
  return false
}

function bindable(hostPort: number, hostIp: string): Promise<boolean> {
  return new Promise((resolve) => {
    const probe = net.createServer()
    probe.unref()
    // Only EADDRINUSE is the collision Docker would hit. EACCES (privileged
    // port, Linux) or EADDRNOTAVAIL (custom host_ip currently unassigned)
    // fail the bind without implying a holder — inconclusive, not taken.
    probe.once('error', (err) => {
      resolve((err as NodeJS.ErrnoException).code !== 'EADDRINUSE')
    })
    probe.listen({ port: hostPort, host: hostIp, exclusive: true }, () => {
      probe.close(() => resolve(true))
    })
  })
}

// Bind probes on the wildcard AND loopback addresses (plus the configured
// host IP if it's something else). One wildcard probe is not enough: Node
// sets SO_REUSEADDR, and on macOS a wildcard bind can coexist with a
// specific-address listener on the same port (and vice versa), so a
// single-address probe reports ports as free that Docker's publish would
// still collide with.
async function isPortFree(hostPort: number, hostIp: string): Promise<boolean> {
  const hosts = [...new Set(['0.0.0.0', '127.0.0.1', hostIp])]
  for (const host of hosts) {
    if (!(await bindable(hostPort, host))) return false
  }
  return true
}

/**
 * Post-mortem for a failed `compose up`: which of this project's published host
 * ports are held by someone else, and by whom. Runs only on the failure path,
 * so it adds no latency to a healthy boot, and whatever caused the bind failure
 * is still holding the port — inspection after the fact is reliable.
 *
 * @param projectDir - The project directory (the compose project root).
 * @returns One entry per conflicting published port (empty when none conflict).
 */
export async function diagnosePortConflicts(projectDir: string): Promise<PortConflict[]> {
  const { name, ports } = await readComposeConfig(projectDir)
  const composeText = readActiveComposeText(projectDir)

  const conflicts: PortConflict[] = []
  for (const { service, hostIp, hostPort } of ports) {
    const hint = PORT_ENV_HINTS[service]
    const envVar = hint && composeInterpolates(composeText, hint) ? hint : undefined
    const holder = await findDockerHolder(hostPort, hostIp)
    if (holder) {
      // Our own warm containers (databases stay up after Ctrl+C by design)
      // hold our own ports legitimately — only a foreign holder is a conflict.
      if (holder.composeProject && holder.composeProject === name) continue
      conflicts.push({ service, hostPort, holder, envVar })
    } else if (!(await isPortFree(hostPort, hostIp))) {
      conflicts.push({ service, hostPort, holder: null, envVar })
    }
  }
  return conflicts
}

// The compose file `docker compose` resolves by default in this project — the
// same one detectProject keys on. Raw text, for checking whether a port is
// env-interpolated (`docker compose config` output has variables already
// substituted, so it can't answer that).
function readActiveComposeText(projectDir: string): string {
  try {
    return fs.readFileSync(path.join(projectDir, 'docker-compose.yml'), 'utf-8')
  } catch {
    return ''
  }
}

// Whether the compose file actually interpolates `varName` — `${VAR}`,
// `${VAR:-default}` (and the other `${VAR<op>…}` forms), or bare `$VAR` — as
// opposed to merely naming it in a comment. Only genuine interpolation means
// setting the override would move the port, so only then do we suggest it.
// Full-line comments are skipped so a commented-out `# ${VAR}` example doesn't
// count. `varName` is a fixed SPREE_* constant, so it needs no regex escaping.
function composeInterpolates(composeText: string, varName: string): boolean {
  const interpolation = new RegExp(`\\$\\{${varName}[}:?+\\-]|\\$${varName}\\b`)
  return composeText
    .split('\n')
    .some((line) => !line.trimStart().startsWith('#') && interpolation.test(line))
}

/**
 * Render {@link diagnosePortConflicts} results into printable lines: each
 * conflict names the port, its holder, and the remedies (stop the other
 * project, or set the `.env` override when the compose interpolates one).
 *
 * @param conflicts - The conflicts to describe.
 * @returns Message lines, with a blank separator line between conflicts.
 */
export function formatPortConflicts(conflicts: PortConflict[]): string[] {
  const blocks = conflicts.map((conflict) => {
    const { service, hostPort, holder, envVar } = conflict
    const port = pc.bold(String(hostPort))
    const sideBySide = envVar
      ? `set ${pc.bold(`${envVar}=<free port>`)} in this project's .env to run both side by side.`
      : `change the ${service} service's published port in docker-compose.yml.`

    if (holder?.composeProject) {
      return [
        `Port ${port} (${service}) is taken by another Docker Compose project, ${pc.bold(holder.composeProject)}`,
        `(container ${holder.container}) — usually another Spree project's services still running warm.`,
        `Run ${pc.bold('spree stop')} in that project (or ${pc.bold(`docker compose -p ${holder.composeProject} stop`)}),`,
        `or ${sideBySide}`,
      ]
    }
    if (holder) {
      return [
        `Port ${port} (${service}) is taken by Docker container ${pc.bold(holder.container)}.`,
        `Stop it (${pc.bold(`docker stop ${holder.container}`)}), or ${sideBySide}`,
      ]
    }
    return [
      `Port ${port} (${service}) is taken by another process on this machine.`,
      `Stop that process, or ${sideBySide}`,
    ]
  })

  return blocks.flatMap((block, index) => (index === 0 ? block : ['', ...block]))
}

/**
 * Diagnose a failed `compose up` and, if any host-port conflicts are found,
 * print the actionable message via `p.cancel`. Shared by dev, init, and eject.
 *
 * @param projectDir - The project directory (the compose project root).
 * @returns `true` when a conflict was reported (the caller should exit),
 *   `false` when none was found (the caller should surface the original error).
 */
export async function cancelOnPortConflict(projectDir: string): Promise<boolean> {
  const conflicts = await diagnosePortConflicts(projectDir).catch(() => [])
  if (conflicts.length === 0) return false
  p.cancel(formatPortConflicts(conflicts).join('\n'))
  return true
}
