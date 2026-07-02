import fs from 'node:fs'
import net from 'node:net'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn() }))

const cancelMock = vi.fn()
vi.mock('@clack/prompts', () => ({ cancel: (...args: unknown[]) => cancelMock(...args) }))

import { execa } from 'execa'
import { cancelOnPortConflict, diagnosePortConflicts, formatPortConflicts } from '../src/ports'

const mockExeca = vi.mocked(execa)

function composeConfigJson(
  name: string,
  services: Record<string, Array<{ host_ip?: string; published?: string | number }>>,
): string {
  return JSON.stringify({
    name,
    services: Object.fromEntries(
      Object.entries(services).map(([service, ports]) => [service, { ports }]),
    ),
  })
}

// Routes the two docker invocations diagnosePortConflicts makes: `compose
// config` returns the project's published ports, `ps --filter publish=N`
// returns `Names\tComposeProject\tPorts` holder lines per port.
function routeExeca(configJson: string, holdersByPort: Record<string, string>): void {
  mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
    if (args.includes('config')) return { stdout: configJson }
    if (args[0] === 'ps') {
      const publishFilter = args[args.indexOf('--filter') + 1] ?? ''
      const port = publishFilter.replace('publish=', '')
      return { stdout: holdersByPort[port] ?? '' }
    }
    throw new Error(`unexpected execa call: ${args.join(' ')}`)
  }) as never)
}

// Occupies a real port so the non-Docker-holder path (bind probe) is exercised
// deterministically.
async function occupyPort(): Promise<{ port: number; close: () => Promise<void> }> {
  const server = net.createServer()
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const address = server.address()
  if (address === null || typeof address === 'string') throw new Error('no port')
  return {
    port: address.port,
    close: () => new Promise((resolve) => server.close(() => resolve())),
  }
}

async function freePort(): Promise<number> {
  const { port, close } = await occupyPort()
  await close()
  return port
}

describe('diagnosePortConflicts', () => {
  const tempDirs: string[] = []

  function projectDirWithCompose(composeText: string): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-ports-test-'))
    tempDirs.push(dir)
    fs.writeFileSync(path.join(dir, 'docker-compose.yml'), composeText)
    return dir
  }

  afterEach(() => {
    mockExeca.mockReset()
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  it('reports a port held by a foreign compose project', async () => {
    routeExeca(
      composeConfigJson('my-shop', { postgres: [{ host_ip: '127.0.0.1', published: '5433' }] }),
      { '5433': 'server-postgres-1\tserver\t127.0.0.1:5433->5432/tcp' },
    )

    const conflicts = await diagnosePortConflicts('/proj')

    expect(conflicts).toEqual([
      {
        service: 'postgres',
        hostPort: 5433,
        holder: { container: 'server-postgres-1', composeProject: 'server' },
        envVar: undefined,
      },
    ])
  })

  it('ignores ports held by this project itself (warm databases)', async () => {
    routeExeca(
      composeConfigJson('my-shop', { postgres: [{ host_ip: '127.0.0.1', published: '5433' }] }),
      { '5433': 'my-shop-postgres-1\tmy-shop\t127.0.0.1:5433->5432/tcp' },
    )

    expect(await diagnosePortConflicts('/proj')).toEqual([])
  })

  it('attributes wildcard-bound holders to loopback-published ports (and vice versa)', async () => {
    routeExeca(
      composeConfigJson('my-shop', { postgres: [{ host_ip: '127.0.0.1', published: '5433' }] }),
      { '5433': 'legacy-postgres-1\tlegacy\t0.0.0.0:5433->5432/tcp, [::]:5433->5432/tcp' },
    )

    const conflicts = await diagnosePortConflicts('/proj')
    expect(conflicts[0]?.holder?.composeProject).toBe('legacy')
  })

  it('does not blame a docker holder bound to a non-overlapping host IP', async () => {
    // docker ps matches publish=N across all interfaces; a 192.0.2.2-bound
    // publish cannot collide with our 127.0.0.1 publish. The bind probe then
    // finds the port genuinely free → no conflict at all.
    const port = await freePort()
    routeExeca(
      composeConfigJson('my-shop', {
        postgres: [{ host_ip: '127.0.0.1', published: String(port) }],
      }),
      { [String(port)]: `other-postgres-1\tother\t192.0.2.2:${port}->5432/tcp` },
    )

    expect(await diagnosePortConflicts('/proj')).toEqual([])
  })

  it('reports a non-compose docker container as the holder', async () => {
    routeExeca(composeConfigJson('my-shop', { postgres: [{ published: 5433 }] }), {
      '5433': 'lonely-postgres\t\t0.0.0.0:5433->5432/tcp',
    })

    const conflicts = await diagnosePortConflicts('/proj')

    expect(conflicts).toEqual([
      {
        service: 'postgres',
        hostPort: 5433,
        holder: { container: 'lonely-postgres', composeProject: '' },
        envVar: undefined,
      },
    ])
  })

  it('reports a non-Docker process via the bind probe', async () => {
    const occupied = await occupyPort()
    try {
      routeExeca(
        composeConfigJson('my-shop', {
          web: [{ host_ip: '127.0.0.1', published: String(occupied.port) }],
        }),
        {},
      )

      const conflicts = await diagnosePortConflicts('/proj')

      expect(conflicts).toEqual([
        { service: 'web', hostPort: occupied.port, holder: null, envVar: undefined },
      ])
    } finally {
      await occupied.close()
    }
  })

  it('returns no conflicts when ports are genuinely free', async () => {
    const port = await freePort()
    routeExeca(
      composeConfigJson('my-shop', { web: [{ host_ip: '127.0.0.1', published: String(port) }] }),
      {},
    )

    expect(await diagnosePortConflicts('/proj')).toEqual([])
  })

  it('attaches the env-var hint only when the compose file interpolates it', async () => {
    // web shows the interpolation only in a commented-out example but pins the
    // real port — a commented `${VAR}` must not trigger the hint, only genuine
    // interpolation on a live line (as postgres has).
    const projectDir = projectDirWithCompose(
      `services:\n  postgres:\n    ports:\n      - "127.0.0.1:\${SPREE_DB_PORT:-5433}:5432"\n  web:\n    ports:\n      # - "\${SPREE_PORT:-3000}:3000"\n      - "3000:3000"\n`,
    )
    routeExeca(
      composeConfigJson('my-shop', {
        postgres: [{ host_ip: '127.0.0.1', published: '5433' }],
        web: [{ published: '3000' }],
      }),
      {
        '5433': 'server-postgres-1\tserver\t127.0.0.1:5433->5432/tcp',
        '3000': 'server-web-1\tserver\t0.0.0.0:3000->3000/tcp',
      },
    )

    const conflicts = await diagnosePortConflicts(projectDir)

    const byService = Object.fromEntries(conflicts.map((c) => [c.service, c.envVar]))
    expect(byService.postgres).toBe('SPREE_DB_PORT')
    // web's port is hardcoded (interpolation only in a comment) → no hint.
    expect(byService.web).toBeUndefined()
  })

  it('skips services without published ports and unparsable mappings', async () => {
    const port = await freePort()
    routeExeca(
      composeConfigJson('my-shop', {
        redis: [],
        web: [{ published: undefined }, { host_ip: '127.0.0.1', published: String(port) }],
      }),
      {},
    )

    expect(await diagnosePortConflicts('/proj')).toEqual([])
    // The undefined mapping never gets a `docker ps` probe.
    const psCalls = mockExeca.mock.calls.filter((call) => (call[1] as string[])[0] === 'ps')
    expect(psCalls).toHaveLength(1)
  })
})

describe('formatPortConflicts', () => {
  it('names the foreign compose project and both remedies', () => {
    const lines = formatPortConflicts([
      {
        service: 'postgres',
        hostPort: 5433,
        holder: { container: 'server-postgres-1', composeProject: 'server' },
        envVar: 'SPREE_DB_PORT',
      },
    ]).join('\n')

    expect(lines).toContain('5433')
    expect(lines).toContain('postgres')
    expect(lines).toContain('server-postgres-1')
    expect(lines).toContain('docker compose -p server stop')
    expect(lines).toContain('spree stop')
    expect(lines).toContain('SPREE_DB_PORT=<free port>')
  })

  it('suggests docker stop for a non-compose container', () => {
    const lines = formatPortConflicts([
      {
        service: 'postgres',
        hostPort: 5433,
        holder: { container: 'lonely-postgres', composeProject: '' },
        envVar: 'SPREE_DB_PORT',
      },
    ]).join('\n')

    expect(lines).toContain('docker stop lonely-postgres')
    expect(lines).toContain('SPREE_DB_PORT=<free port>')
  })

  it('falls back to editing the compose file when no env var moves the port', () => {
    // A service with no env override (e.g. meilisearch, not host-published in
    // the starter) points the user at the compose file instead.
    const lines = formatPortConflicts([
      { service: 'meilisearch', hostPort: 7700, holder: null },
    ]).join('\n')

    expect(lines).toContain('another process on this machine')
    expect(lines).toContain('docker-compose.yml')
    expect(lines).not.toContain('SPREE_MEILISEARCH_PORT')
  })
})

describe('cancelOnPortConflict', () => {
  afterEach(() => {
    mockExeca.mockReset()
    cancelMock.mockReset()
  })

  it('cancels and returns true when a conflict is found', async () => {
    routeExeca(
      composeConfigJson('my-shop', { postgres: [{ host_ip: '127.0.0.1', published: '5433' }] }),
      { '5433': 'server-postgres-1\tserver\t127.0.0.1:5433->5432/tcp' },
    )

    expect(await cancelOnPortConflict('/proj')).toBe(true)
    expect(cancelMock).toHaveBeenCalledOnce()
    expect(cancelMock.mock.calls[0][0]).toContain('5433')
  })

  it('returns false without cancelling when nothing is holding the ports', async () => {
    const port = await freePort()
    routeExeca(
      composeConfigJson('my-shop', { web: [{ host_ip: '127.0.0.1', published: String(port) }] }),
      {},
    )

    expect(await cancelOnPortConflict('/proj')).toBe(false)
    expect(cancelMock).not.toHaveBeenCalled()
  })

  it('swallows a diagnosis failure (e.g. daemon down) and returns false', async () => {
    mockExeca.mockRejectedValue(new Error('Cannot connect to the Docker daemon'))

    expect(await cancelOnPortConflict('/proj')).toBe(false)
    expect(cancelMock).not.toHaveBeenCalled()
  })
})
