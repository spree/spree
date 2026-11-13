// Helpers the runner and the task checks share: running commands, scaffolding
// a fresh project, minting keys and calling the Store and Admin APIs.
import { spawn } from 'node:child_process'
import crypto from 'node:crypto'
import fs from 'node:fs'
import net from 'node:net'
import path from 'node:path'

// Runs a command and resolves with its exit code and output. Never rejects on
// a non-zero exit: checks decide what a failure means.
export function sh(command, args, { cwd, env, timeoutMs = 30 * 60_000, input, onStdout } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd,
      env: { ...process.env, ...env },
      stdio: ['pipe', 'pipe', 'pipe'],
    })
    let stdout = ''
    let stderr = ''
    const timer = setTimeout(() => child.kill('SIGTERM'), timeoutMs)
    child.stdout.on('data', (chunk) => {
      stdout += chunk
      onStdout?.(chunk)
    })
    child.stderr.on('data', (chunk) => {
      stderr += chunk
    })
    child.on('error', (error) => {
      stderr += String(error)
    })
    child.on('close', (code, signal) => {
      clearTimeout(timer)
      resolve({ code: code ?? 1, signal, stdout, stderr, timedOut: signal === 'SIGTERM' })
    })
    if (input) child.stdin.write(input)
    child.stdin.end()
  })
}

export async function freePort(from = 3000) {
  for (let port = from; port < from + 500; port++) {
    const free = await new Promise((resolve) => {
      const server = net.createServer()
      server.once('error', () => resolve(false))
      server.listen(port, '127.0.0.1', () => server.close(() => resolve(true)))
    })
    if (free) return port
  }
  throw new Error(`No free port from ${from}`)
}

export const spree = (projectDir, args, options = {}) =>
  sh('npx', ['--no-install', 'spree', ...args], { cwd: projectDir, ...options })

// Scaffolds the project the way a developer would, minus the questions.
export async function scaffoldProject({
  workDir,
  port,
  createCommand,
  imageTag,
  devImage,
  storefront,
}) {
  const [command, ...baseArgs] = createCommand.split(' ')
  const args = [
    ...baseArgs,
    'app',
    '--use-npm',
    '--no-start',
    '--no-seller-dashboard',
    '--agent-skills',
    '--docs-mcp',
    '--port',
    String(port),
  ]
  if (!storefront) args.push('--no-storefront')
  const created = await sh(command, args, { cwd: workDir, env: { CI: '1' } })
  const projectDir = path.join(workDir, 'app')
  if (created.code !== 0) {
    throw new Error(`create-spree-app failed:\n${created.stdout}\n${created.stderr}`)
  }

  if (imageTag) {
    const envPath = path.join(projectDir, '.env')
    const env = fs.readFileSync(envPath, 'utf8')
    fs.writeFileSync(
      envPath,
      env.replace(/^SPREE_VERSION_TAG=.*$/m, `SPREE_VERSION_TAG=${imageTag}`),
    )
  }

  // Ejecting builds server/Dockerfile's dev stage, which needs the Debian
  // mirrors. Where they are unreachable, a prebuilt dev image stands in for
  // it (see dev-image/Dockerfile).
  if (devImage) {
    const devCompose = path.join(projectDir, 'docker-compose.dev.yml')
    const source = fs.readFileSync(devCompose, 'utf8')
    // The build: key stays: the CLI reads it as the mark of an ejected project.
    const swapped = source.replace(
      /^( {4})dockerfile: .*\n {4}target: dev\n/m,
      `$1dockerfile_inline: FROM ${devImage}\n`,
    )
    if (swapped === source) throw new Error(`No dev build to replace in ${devCompose}`)
    fs.writeFileSync(devCompose, swapped)
  }

  const admin = {
    email: 'benchmark@example.com',
    password: crypto.randomBytes(12).toString('hex'),
  }
  const init = await spree(projectDir, [
    'init',
    '--no-sample-data',
    '--no-open',
    // Without it init stays attached to the logs and never returns.
    '--detach',
    '--admin-email',
    admin.email,
    '--admin-password',
    admin.password,
  ])
  if (init.code !== 0) throw new Error(`spree init failed:\n${init.stdout}\n${init.stderr}`)
  await waitForServer(port)

  return { projectDir, admin, keys: await mintKeys(projectDir) }
}

async function mintKey(projectDir, type, scopes) {
  const args = ['api-key', 'create', '--name', `benchmark-${type}`, '--type', type]
  if (scopes) args.push('--scopes', scopes)
  const result = await spree(projectDir, args)
  const prefix = type === 'secret' ? 'sk_' : 'pk_'
  // biome-ignore lint/suspicious/noControlCharactersInRegex: strips ANSI colours
  const plain = result.stdout.replace(/\u001b\[[0-9;]*m/g, '')
  const token = plain.match(new RegExp(`${prefix}[A-Za-z0-9_-]{8,}`))?.[0]
  if (!token) throw new Error(`Could not mint a ${type} key:\n${plain}\n${result.stderr}`)
  return token
}

// The harness's own keys. They live outside the project, so the agent never
// sees them.
export async function mintKeys(projectDir) {
  return {
    publishable: await mintKey(projectDir, 'publishable'),
    secret: await mintKey(projectDir, 'secret', 'write_all'),
  }
}

export async function waitForServer(port, timeoutMs = 5 * 60_000) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://localhost:${port}/up`)
      if (response.ok) return true
    } catch {
      // Not listening yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 2000))
  }
  return false
}

// The starter only runs code from the project once it is ejected: the
// compose file then mounts ./server into the container.
export function isEjected(projectDir) {
  const compose = path.join(projectDir, 'docker-compose.yml')
  return fs.existsSync(compose) && /\.\/server:\/rails/.test(fs.readFileSync(compose, 'utf8'))
}

export function apiClient(port, keys) {
  const base = `http://localhost:${port}/api/v3`
  const call = async (surface, method, pathname, { body, headers = {} } = {}) => {
    const key = surface === 'admin' ? keys.secret : keys.publishable
    const response = await fetch(`${base}/${surface}${pathname}`, {
      method,
      headers: { 'content-type': 'application/json', 'x-spree-api-key': key, ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
    const text = await response.text()
    let json = null
    try {
      json = text ? JSON.parse(text) : null
    } catch {
      // Keep the raw text for the failure details.
    }
    return { status: response.status, json, text }
  }
  return {
    admin: (method, pathname, options) => call('admin', method, pathname, options),
    store: (method, pathname, options) => call('store', method, pathname, options),
  }
}

// Creates an active product with one priced, stocked variant through the
// Admin API, for checks that need something to sell.
export async function createProduct(api, { name, sku, amount = '19.99', currency = 'USD' }) {
  const locations = await api.admin('GET', '/stock_locations')
  const stockLocationId = locations.json?.data?.[0]?.id
  const variant = { sku, prices: [{ currency, amount }] }
  if (stockLocationId) {
    variant.stock_levels = [{ stock_location_id: stockLocationId, count_on_hand: 100 }]
  }
  const created = await api.admin('POST', '/products', {
    body: { name, status: 'active', variants: [variant] },
  })
  if (created.status >= 300) {
    throw new Error(`Creating product ${name} failed (${created.status}): ${created.text}`)
  }
  return created.json
}

// Copies a hidden spec into the project and runs it in the test environment.
export async function runAcceptanceSpec(projectDir, name, source) {
  if (!isEjected(projectDir)) {
    return {
      passed: false,
      details: 'The project was never ejected, so the changes never reached the container.',
    }
  }
  const relative = `spec/agent_benchmark/${name}_spec.rb`
  const file = path.join(projectDir, 'server', relative)
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, source)
  try {
    await spree(projectDir, ['rails', 'db:test:prepare'])
    const result = await spree(projectDir, ['test', relative, '--format', 'documentation'])
    return { passed: result.code === 0, details: `${result.stdout}\n${result.stderr}`.trim() }
  } finally {
    fs.rmSync(path.dirname(file), { recursive: true, force: true })
  }
}
