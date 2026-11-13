import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

/** The Spree base image every project Dockerfile and development container builds on. */
export const BASE_IMAGE = 'ghcr.io/spree/spree-base'

/**
 * The base image line for a Spree version: its minor line. Undefined before
 * 6.1, the first line a base image was published for, and for a version that
 * cannot be read.
 */
export function baseImageLine(version: string): string | undefined {
  const match = version.match(/^(\d+)\.(\d+)\./)
  if (!match) return undefined
  const [major, minor] = [Number(match[1]), Number(match[2])]
  if (major < 6 || (major === 6 && minor < 1)) return undefined
  return `${major}.${minor}`
}

/** Whether a Dockerfile already builds on the base image. */
export function usesBaseImage(dockerfile: string): boolean {
  return /\bspree-image-build\b/.test(dockerfile)
}

/**
 * The Dockerfile a project builds its production image with. Kept identical
 * to docker/project/Dockerfile in the monorepo, the canonical copy.
 */
export function projectDockerfile(line: string): string {
  return `# syntax=docker/dockerfile:1

# Builds this project's production image on the Spree base image. The base
# holds Ruby, Node and the system libraries; \`spree-image-build\` installs the
# gems and builds the app and the dashboards. Rebuilding picks up the base's
# security fixes. To pin a build, set SPREE_BASE to a dated tag such as
# ${BASE_IMAGE}:${line}-202611160323.
#
# The build context is the project root of a create-spree-app project, or the
# Rails app itself in a bare clone of spree-starter.
ARG SPREE_BASE=${BASE_IMAGE}:${line}

FROM \${SPREE_BASE}-build AS build

# Gems first, in their own layer: a code change does not reinstall them.
# The Gemfile sits at the context root, or under server/ (backend/ in older
# projects). `[s]erver` is a wildcard, so a directory that is absent is skipped
# where a plain `server/` would fail the build.
COPY --chown=rails:rails Gemfile* .ruby-version* [s]erver/Gemfile* [s]erver/.ruby-version* [b]ackend/Gemfile* [b]ackend/.ruby-version* ./
RUN spree-image-build gems

COPY . /src
RUN spree-image-build app /src

FROM \${SPREE_BASE}

COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails /rails
`
}

// sha256 of every Dockerfile spree-starter has shipped, line endings
// normalized. A Dockerfile that matches none of them has been changed by the
// project and is never overwritten.
const STOCK_DOCKERFILES = new Set([
  '1e219ae136d6021b936081a220a9fad2ea7aa71b691dbbde99267ed7200b9109',
  '1f4fe1dd3445fb0dac80c2a20b98616571c9ab8d1a738ce092f5ab64c19d5647',
  '32df84f6725c5c7882fbb1bf4e09eeb5bfcae0a31f7251e52b2703948b7434fe',
  '3f55173b7292144dbcbdaa9aac86e2c86a1553c424de291e59a2dc4e212f6cec',
  '44d2e633e864d8970d1af206779dc95231a3d974649d131d6e809675379782b1',
  '45c7525fe0dab966213db76ae8ffef03fed01f301ec44c1720569156b9f528cb',
  '46a95086267563412f1b2f8dc24621e2891b2cc59db6116164c011db27625b6f',
  '484d025072c29f9f5527d1ffd99787f9a7702952e84ba300f7e0680f18595c97',
  '4947bf5a57bd52637d3e747c9fdeec28110961210c70d015ab26598772d11d2a',
  '6a09887535fdb8e9ace10f2ca28182a8b2c240429a67188a05e46b62743d67c0',
  '6f7ce40e08177e1e6c2ee571074aeb47efc1b3f141a8461c0f997379b1d6d308',
  '9d507b128009b7da6c2baf1ba0547cd1bfd5eaa8e535cd51654bd3a5954e46c8',
  'a6d0d5f9ed70be584a14e056751c3a5fafe6baef4711cbd40eef48b374369751',
  'af56d0d69b82bf2e00b519d3bb460f0812cb3380755c68d0a26220e3bdfec19a',
  'b1d20ea929d2b41a0d311676cf691fcac6f372366b47a211aeec171f1650c89b',
  'b38001ccf462dc67773a094664be458e59f5f5ea1552998c017de407ce34409e',
  'c7700ae473753362e8d8ef7098d6e1b928baeecfac3ae05abee17bc93cb27428',
  'e9a75ced4ff1d2932580dad22ccba92450873c69dccc7eb197bcde931dc45fa4',
])

export function isStockDockerfile(content: string): boolean {
  const hash = crypto.createHash('sha256').update(content.replace(/\r/g, '')).digest('hex')
  return STOCK_DOCKERFILES.has(hash)
}

// The `build:` block every stock development compose file carries, with or
// without the `dev` target older Dockerfiles lacked. The lookahead refuses a
// block with any further key, which is the project's own.
const STOCK_BUILD_BLOCK =
  /^([ \t]*)build:\n\1[ \t]+context: \S+\n\1[ \t]+dockerfile: Dockerfile\n(?:\1[ \t]+target: dev\n)?(?!\1[ \t]+\S)/m

/** Whether a compose file builds an image itself, rather than running a published one. */
export function composeBuildsImage(content: string): boolean {
  return /^\s*build\s*:/m.test(content)
}

/**
 * A development compose file switched from building the project's Dockerfile
 * to running the base image's build variant. Null when its `build:` block is
 * not the stock one.
 */
export function composeOnBaseImage(content: string, line: string): string | null {
  const block = content.match(STOCK_BUILD_BLOCK)
  if (!block) return null

  const indent = block[1]
  const image = `${indent}image: ${BASE_IMAGE}:${line}-build\n`
  const start = block.index ?? 0
  const before = content.slice(0, start)
  const after = content.slice(start + block[0].length)

  // The rest of the mapping the build block sat in: up to the first line
  // indented less than it. The variables belong there, not in another service.
  const outdent = after.search(new RegExp(`^(?!${indent})[ \\t]*[^\\s#]`, 'm'))
  const mapping = outdent === -1 ? after : after.slice(0, outdent)
  const rest = outdent === -1 ? '' : after.slice(outdent)

  // The old development image set these itself; the base image is built for
  // production, so the compose file has to.
  const development = [
    ['RAILS_ENV', 'development'],
    ['BUNDLE_DEPLOYMENT', '"0"'],
    ['BUNDLE_WITHOUT', '""'],
  ]
    .filter(([name]) => !new RegExp(`^${indent}[ \\t]+${name}:`, 'm').test(mapping))
    .map(([name, value]) => `${indent}  ${name}: ${value}\n`)
    .join('')

  const environment = new RegExp(`^${indent}environment:\\n`, 'm')
  if (environment.test(mapping)) {
    return before + image + mapping.replace(environment, (key) => key + development) + rest
  }
  const added = development ? `${indent}environment:\n${development}` : ''
  return before + image + added + mapping + rest
}

/**
 * A Gemfile whose exact Ruby pin (`ruby file: '.ruby-version'`) is loosened to
 * the minor: the base image decides the patch version, so a base rebuild that
 * moves it must not break the build. Null when there is nothing to loosen.
 */
export function withLooseRubyPin(gemfile: string, rubyVersion: string | undefined): string | null {
  const pin = /^ruby file: ['"]\.ruby-version['"][ \t]*$/m
  const minor = rubyVersion?.trim().match(/^(\d+\.\d+)\./)?.[1]
  if (!minor || !pin.test(gemfile)) return null
  return gemfile.replace(pin, `ruby '~> ${minor}.0'`)
}

export interface BaseImageMove {
  /** Files to write, in order. Empty when there is nothing to do. */
  writes: { file: string; content: string }[]
  /** Why the project was left alone, when it was. */
  skipped?: string
}

/**
 * What moving a project's Docker build onto the base image would write. All
 * or nothing: the thin Dockerfile has no `dev` target, so a compose file that
 * still builds one must move with it.
 */
export function planBaseImageMove(
  projectDir: string,
  apiDir: string,
  line: string,
  isStock: (dockerfile: string) => boolean = isStockDockerfile,
): BaseImageMove {
  const nested = path.join(projectDir, apiDir)
  const appDir = fs.existsSync(path.join(nested, 'Gemfile')) ? nested : projectDir
  const relative = (file: string) => path.relative(projectDir, file) || path.basename(file)

  const dockerfile = path.join(appDir, 'Dockerfile')
  if (!fs.existsSync(dockerfile)) return { writes: [] }
  const current = fs.readFileSync(dockerfile, 'utf-8')
  if (usesBaseImage(current)) return { writes: [] }
  if (!isStock(current)) {
    return { writes: [], skipped: `${relative(dockerfile)} has changes of your own` }
  }

  const writes: BaseImageMove['writes'] = []
  for (const name of ['docker-compose.dev.yml', 'docker-compose.yml']) {
    const file = path.join(projectDir, name)
    if (!fs.existsSync(file)) continue
    const compose = fs.readFileSync(file, 'utf-8')
    if (!composeBuildsImage(compose)) continue
    const moved = composeOnBaseImage(compose, line)
    if (!moved) return { writes: [], skipped: `${name} has a build section of your own` }
    writes.push({ file, content: moved })
  }

  writes.push({ file: dockerfile, content: projectDockerfile(line) })

  const gemfile = path.join(appDir, 'Gemfile')
  const rubyVersion = path.join(appDir, '.ruby-version')
  if (fs.existsSync(gemfile) && fs.existsSync(rubyVersion)) {
    const loosened = withLooseRubyPin(
      fs.readFileSync(gemfile, 'utf-8'),
      fs.readFileSync(rubyVersion, 'utf-8'),
    )
    if (loosened) writes.push({ file: gemfile, content: loosened })
  }

  return { writes }
}
