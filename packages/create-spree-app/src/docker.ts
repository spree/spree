import { execa } from 'execa'
import { HEALTH_CHECK_INTERVAL_MS, HEALTH_CHECK_TIMEOUT_MS } from './constants.js'

export async function startServices(projectDir: string): Promise<void> {
  await execa('docker', ['compose', 'up', '-d'], { cwd: projectDir, stdio: 'ignore' })
}

export async function waitForHealthy(port: number): Promise<void> {
  const url = `http://localhost:${port}/up`
  const start = Date.now()

  while (Date.now() - start < HEALTH_CHECK_TIMEOUT_MS) {
    try {
      const res = await fetch(url)
      if (res.ok) return
    } catch {
      // not ready yet
    }
    await sleep(HEALTH_CHECK_INTERVAL_MS)
  }

  throw new Error(`Spree did not become healthy within ${HEALTH_CHECK_TIMEOUT_MS / 1000}s`)
}

export async function fetchApiKey(projectDir: string): Promise<string> {
  const script = [
    'store = Spree::Store.default;',
    'key = store.api_keys.active.publishable.first ||',
    "  store.api_keys.create!(name: 'Default', key_type: 'publishable');",
    'print key.token',
  ].join(' ')

  const { stdout } = await execa(
    'docker',
    ['compose', 'exec', '-T', 'web', 'bin/rails', 'runner', script],
    { cwd: projectDir },
  )

  // Rails boot may print noise (e.g. "[Spree Events] ...") to stdout — extract just the token
  const match = stdout.match(/pk_[A-Za-z0-9]+/)
  if (!match) {
    throw new Error(`Could not extract API key from Rails output: ${stdout}`)
  }
  return match[0]
}

export async function loadSampleData(projectDir: string): Promise<void> {
  await execa(
    'docker',
    ['compose', 'exec', '-T', 'web', 'bin/rails', 'spree:load_sample_data'],
    { cwd: projectDir, stdio: 'ignore' },
  )
}

export async function streamLogs(projectDir: string): Promise<void> {
  await execa('docker', ['compose', 'logs', '-f', 'web'], {
    cwd: projectDir,
    stdio: 'inherit',
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
