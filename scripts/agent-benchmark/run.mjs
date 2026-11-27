#!/usr/bin/env node
// Runs coding agents headless against benchmark tasks on fresh Spree projects,
// keeps each transcript, diff and acceptance result, then writes a report.
// See scripts/agent-benchmark/README.md.
//
//   node scripts/agent-benchmark/run.mjs [--task id,id|all]
//     [--agent claude|codex|cursor|baseline|eject-only|reference] [--repeat N] [--model name]
//     [--out dir] [--image-tag tag] [--dev-image image]
//     [--create-command "npx --yes create-spree-app@latest"] [--keep]
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { parseArgs } from 'node:util'
import { AGENTS } from './lib/agents.mjs'
import {
  freePort,
  isEjected,
  mintKeys,
  projectDirFor,
  scaffoldProject,
  sh,
  spree,
  waitForServer,
} from './lib/project.mjs'
import { loadTasks } from './lib/tasks.mjs'
import { writeReport } from './score.mjs'

const { values: options } = parseArgs({
  options: {
    task: { type: 'string', default: 'all' },
    agent: { type: 'string', default: 'claude' },
    repeat: { type: 'string', default: '1' },
    model: { type: 'string' },
    out: { type: 'string' },
    'image-tag': { type: 'string' },
    'dev-image': { type: 'string' },
    'create-command': { type: 'string', default: 'npx --yes create-spree-app@latest' },
    keep: { type: 'boolean', default: false },
    help: { type: 'boolean', short: 'h', default: false },
  },
})

if (options.help) {
  console.log(
    fs
      .readFileSync(new URL(import.meta.url), 'utf8')
      .split('\n')
      .slice(1, 9)
      .join('\n'),
  )
  process.exit(0)
}

const agent = AGENTS[options.agent]
if (!agent) {
  console.error(`Unknown agent ${options.agent}. Known: ${Object.keys(AGENTS).join(', ')}`)
  process.exit(64)
}

const allTasks = await loadTasks()
const wanted = options.task === 'all' ? allTasks.map((task) => task.id) : options.task.split(',')
const tasks = wanted.map((id) => {
  const task = allTasks.find((candidate) => candidate.id === id)
  if (!task) {
    console.error(`Unknown task ${id}. Known: ${allTasks.map((t) => t.id).join(', ')}`)
    process.exit(64)
  }
  return task
})

const stamp = new Date().toISOString().replace(/[:.]/g, '-')
const outDir = path.resolve(options.out ?? path.join(os.tmpdir(), 'spree-agent-benchmark', stamp))
fs.mkdirSync(outDir, { recursive: true })

const log = (message) => console.log(`[${new Date().toISOString().slice(11, 19)}] ${message}`)

async function runOnce(task, attempt) {
  const runDir = path.join(outDir, `${task.id}--${options.agent}--${attempt}`)
  // A rerun into the same --out must not score an earlier run's artifacts.
  fs.rmSync(runDir, { recursive: true, force: true })
  fs.mkdirSync(runDir, { recursive: true })
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-bench-'))
  const startedAt = new Date()
  const meta = {
    task: task.id,
    agent: options.agent,
    format: agent.format,
    model: options.model ?? null,
    attempt,
    startedAt: startedAt.toISOString(),
    imageTag: options['image-tag'] ?? null,
    devImage: options['dev-image'] ?? null,
    createCommand: options['create-command'],
    workDir,
  }
  let projectDir = null
  // Set before scaffolding, so a scaffold that fails after starting
  // containers is still torn down.
  let composeDir = null
  let baseCommit = 'HEAD'
  let ctx = { workDir }
  let scaffoldEjected = false

  try {
    if (task.project) {
      const port = await freePort(3000)
      log(`${task.id} #${attempt}: scaffolding a project on port ${port}`)
      composeDir = projectDirFor(workDir)
      const scaffold = await scaffoldProject({
        workDir,
        port,
        createCommand: options['create-command'],
        imageTag: options['image-tag'],
        devImage: options['dev-image'],
        storefront: task.project.storefront,
      })
      projectDir = scaffold.projectDir
      ctx = { ...ctx, projectDir, port, keys: scaffold.keys, admin: scaffold.admin }
      meta.port = port
      scaffoldEjected = isEjected(projectDir)
      // A baseline commit, so everything the agent changes shows in one diff.
      await sh('git', ['init', '-q'], { cwd: projectDir })
      await sh('git', ['add', '-A'], { cwd: projectDir })
      await sh(
        'git',
        [
          '-c',
          'user.name=benchmark',
          '-c',
          'user.email=benchmark@example.com',
          'commit',
          '-qm',
          'Scaffold',
        ],
        {
          cwd: projectDir,
        },
      )
      // The diff base: an agent that commits its work must still show it all.
      const head = await sh('git', ['rev-parse', 'HEAD'], { cwd: projectDir })
      if (head.code === 0) baseCommit = head.stdout.trim()
    }

    const cwd = projectDir ?? workDir
    fs.writeFileSync(path.join(runDir, 'prompt.txt'), task.prompt)
    const [command, args] = agent.command(task.prompt, { model: options.model, cwd, task: task.id })
    const transcript = fs.createWriteStream(path.join(runDir, 'transcript.jsonl'))
    log(`${task.id} #${attempt}: running ${options.agent}`)
    const agentStart = Date.now()
    const result = await sh(command, args, {
      cwd,
      timeoutMs: task.timeoutMinutes * 60_000,
      onStdout: (chunk) => transcript.write(chunk),
    })
    await new Promise((resolve) => transcript.end(resolve))
    fs.writeFileSync(path.join(runDir, 'stderr.log'), result.stderr)
    meta.agentExitCode = result.code
    meta.agentTimedOut = result.timedOut
    meta.agentSignal = result.signal ?? null
    meta.agentWallMs = Date.now() - agentStart

    if (projectDir) {
      await sh('git', ['add', '-A'], { cwd: projectDir })
      const diff = await sh('git', ['diff', '--cached', baseCommit], { cwd: projectDir })
      fs.writeFileSync(path.join(runDir, 'diff.patch'), diff.stdout)
      // Judge the code, not whether the agent remembered to restart.
      await spree(projectDir, ['restart'])
      await waitForServer(ctx.port)
      // Ejecting moves the app to a new database, which has none of the
      // harness's keys: mint them again there.
      if (isEjected(projectDir) && !scaffoldEjected) {
        ctx = { ...ctx, keys: await mintKeys(projectDir) }
        meta.keysRemintedAfterEject = true
      }
    } else if (fs.existsSync(path.join(workDir, 'ANSWER.md'))) {
      fs.copyFileSync(path.join(workDir, 'ANSWER.md'), path.join(runDir, 'ANSWER.md'))
    }

    log(`${task.id} #${attempt}: checking`)
    let acceptance
    try {
      acceptance = await task.check(ctx)
    } catch (error) {
      acceptance = { passed: false, details: `The check crashed: ${error.stack ?? error}` }
    }
    fs.writeFileSync(path.join(runDir, 'acceptance.json'), JSON.stringify(acceptance, null, 2))
    log(`${task.id} #${attempt}: ${acceptance.passed ? 'passed' : 'failed'}`)
  } catch (error) {
    meta.harnessError = String(error.stack ?? error)
    log(`${task.id} #${attempt}: harness error: ${error.message}`)
  } finally {
    meta.wallMs = Date.now() - startedAt.getTime()
    fs.writeFileSync(path.join(runDir, 'meta.json'), JSON.stringify(meta, null, 2))
    if (!options.keep) {
      await teardown(workDir, composeDir)
    } else {
      log(`${task.id} #${attempt}: kept ${workDir}`)
    }
  }
}

async function teardown(workDir, composeDir) {
  if (composeDir && fs.existsSync(composeDir)) {
    // The --dev-image container runs as root, so files it wrote into the
    // bind-mounted server/ may be root-owned: hand them back to this user.
    const serverDir = path.join(composeDir, 'server')
    const uid = process.getuid?.()
    // Only a real directory inside the project: never follow a symlink out of it.
    const inProject =
      fs.existsSync(serverDir) &&
      !fs.lstatSync(serverDir).isSymbolicLink() &&
      fs.realpathSync(serverDir).startsWith(fs.realpathSync(composeDir) + path.sep)
    if (options['dev-image'] && uid && inProject) {
      await sh('docker', [
        'run',
        '--rm',
        '--entrypoint',
        'chown',
        '-v',
        `${serverDir}:/rails`,
        options['dev-image'],
        '-R',
        `${uid}:${process.getgid()}`,
        '/rails',
      ])
    }
    // The containers and volumes belong to this throwaway project only.
    const down = await sh('docker', ['compose', 'down', '-v', '--remove-orphans'], {
      cwd: composeDir,
    })
    if (down.code !== 0 || down.timedOut) {
      // Keep the compose files so the containers and volumes can still be removed.
      log(
        `docker compose down failed (${down.timedOut ? 'timed out' : `exit ${down.code}`}); ` +
          `kept ${workDir}; run \`docker compose down -v\` in ${composeDir} to finish: ${down.stderr.trim().split('\n').pop() ?? ''}`,
      )
      return
    }
  }
  try {
    fs.rmSync(workDir, { recursive: true, force: true })
  } catch (error) {
    // A leftover directory must not stop later attempts or the report.
    log(`could not remove ${workDir}: ${error.message}`)
  }
}

const repeat = Number(options.repeat)
for (const task of tasks) {
  for (let attempt = 1; attempt <= repeat; attempt++) await runOnce(task, attempt)
}

const { markdownPath } = writeReport(outDir)
log(`Report: ${markdownPath}`)
