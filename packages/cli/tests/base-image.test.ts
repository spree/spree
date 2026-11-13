import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import {
  baseImageLine,
  composeOnBaseImage,
  isStockDockerfile,
  onBaseImageLine,
  planBaseImageMove,
  projectDockerfile,
  usesBaseImage,
  withLooseRubyPin,
} from '../src/lib/base-image.js'

const STOCK_DEV_COMPOSE = `x-app: &app
  build:
    context: ./server
    dockerfile: Dockerfile
    target: dev
  env_file: .env
  environment:
    DATABASE_HOST: postgres
  volumes:
    - ./server:/rails
    - bundle_cache:/usr/local/bundle

services:
  web:
    <<: *app
`

describe('baseImageLine', () => {
  it('is the minor line of a Spree version', () => {
    expect(baseImageLine('6.1.0')).toBe('6.1')
    expect(baseImageLine('6.2.3')).toBe('6.2')
    expect(baseImageLine('6.1.0-rc.1')).toBe('6.1')
    expect(baseImageLine('7.0.0')).toBe('7.0')
  })

  it('is undefined before the first line with a base image', () => {
    expect(baseImageLine('6.0.4')).toBeUndefined()
    expect(baseImageLine('5.4.2')).toBeUndefined()
    expect(baseImageLine('not a version')).toBeUndefined()
  })
})

describe('projectDockerfile', () => {
  // docker/project/Dockerfile is the canonical copy; spree-starter ships it
  // and CI builds it. The one the CLI writes must not drift from it.
  it('matches the canonical Dockerfile in the monorepo', () => {
    const canonical = fs.readFileSync(
      path.resolve(__dirname, '../../../docker/project/Dockerfile'),
      'utf-8',
    )
    const line = canonical.match(/^ARG SPREE_BASE=ghcr\.io\/spree\/spree-base:(\S+)$/m)?.[1]
    expect(line).toBeDefined()
    expect(projectDockerfile(line as string)).toBe(canonical)
  })

  it('names the base image of the given line', () => {
    expect(projectDockerfile('6.2')).toContain('ARG SPREE_BASE=ghcr.io/spree/spree-base:6.2\n')
    expect(usesBaseImage(projectDockerfile('6.2'))).toBe(true)
  })
})

describe('isStockDockerfile', () => {
  it('is false for a Dockerfile the starter never shipped', () => {
    expect(isStockDockerfile('FROM ruby:4.0\nRUN echo mine\n')).toBe(false)
    expect(isStockDockerfile(projectDockerfile('6.1'))).toBe(false)
  })
})

describe('composeOnBaseImage', () => {
  it('swaps the stock build block for the build image and sets the development environment', () => {
    expect(composeOnBaseImage(STOCK_DEV_COMPOSE, '6.1')).toBe(`x-app: &app
  image: ghcr.io/spree/spree-base:6.1-build
  env_file: .env
  environment:
    RAILS_ENV: development
    BUNDLE_DEPLOYMENT: "0"
    BUNDLE_WITHOUT: ""
    DATABASE_HOST: postgres
  volumes:
    - ./server:/rails
    - bundle_cache:/usr/local/bundle

services:
  web:
    <<: *app
`)
  })

  it('handles a build block without the dev target and without an environment key', () => {
    const compose =
      'services:\n  web:\n    build:\n      context: .\n      dockerfile: Dockerfile\n    ports:\n      - "3000:3000"\n'
    expect(composeOnBaseImage(compose, '6.1')).toBe(
      'services:\n  web:\n    image: ghcr.io/spree/spree-base:6.1-build\n    environment:\n      RAILS_ENV: development\n      BUNDLE_DEPLOYMENT: "0"\n      BUNDLE_WITHOUT: ""\n    ports:\n      - "3000:3000"\n',
    )
  })

  it('is null for a build block the project has changed', () => {
    const custom = STOCK_DEV_COMPOSE.replace(
      'dockerfile: Dockerfile',
      'dockerfile: Dockerfile.custom',
    )
    expect(composeOnBaseImage(custom, '6.1')).toBeNull()
  })
})

describe('withLooseRubyPin', () => {
  it('lets the base image decide the Ruby patch version', () => {
    const gemfile = "source 'https://rubygems.org'\nruby file: '.ruby-version'\n\ngem 'spree'\n"
    expect(withLooseRubyPin(gemfile, '4.0.9\n')).toBe(
      "source 'https://rubygems.org'\nruby '~> 4.0.0'\n\ngem 'spree'\n",
    )
  })

  it('is null when the Gemfile has no exact pin, or the version cannot be read', () => {
    expect(withLooseRubyPin("ruby '~> 4.0.0'\n", '4.0.9')).toBeNull()
    expect(withLooseRubyPin("ruby file: '.ruby-version'\n", undefined)).toBeNull()
    expect(withLooseRubyPin("ruby file: '.ruby-version'\n", 'ruby-head')).toBeNull()
  })
})

describe('planBaseImageMove', () => {
  let projectDir: string
  const stock = () => true
  const changed = () => false

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-base-image-'))
    fs.mkdirSync(path.join(projectDir, 'server'))
    fs.writeFileSync(path.join(projectDir, 'server', 'Dockerfile'), 'FROM ruby AS dev\n')
    fs.writeFileSync(path.join(projectDir, 'server', 'Gemfile'), "ruby file: '.ruby-version'\n")
    fs.writeFileSync(path.join(projectDir, 'server', '.ruby-version'), '4.0.9\n')
    fs.writeFileSync(path.join(projectDir, 'docker-compose.dev.yml'), STOCK_DEV_COMPOSE)
    fs.writeFileSync(
      path.join(projectDir, 'docker-compose.yml'),
      'services:\n  web:\n    image: ghcr.io/spree/spree:latest\n',
    )
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
  })

  const written = (move: ReturnType<typeof planBaseImageMove>) =>
    move.writes.map(({ file }) => path.relative(projectDir, file))

  it('moves the Dockerfile, the development compose file and the Ruby pin together', () => {
    const move = planBaseImageMove(projectDir, 'server', '6.1', stock)

    expect(move.skipped).toBeUndefined()
    expect(written(move)).toEqual(['docker-compose.dev.yml', 'server/Dockerfile', 'server/Gemfile'])
    expect(move.writes[1].content).toBe(projectDockerfile('6.1'))
  })

  it('also moves the active compose file of an ejected project', () => {
    fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), STOCK_DEV_COMPOSE)

    const move = planBaseImageMove(projectDir, 'server', '6.1', stock)

    expect(written(move)).toContain('docker-compose.yml')
  })

  it('leaves a Dockerfile the project has changed alone, and says so', () => {
    const move = planBaseImageMove(projectDir, 'server', '6.1', changed)

    expect(move.writes).toEqual([])
    expect(move.skipped).toBe('server/Dockerfile has changes of your own')
  })

  it('writes nothing when a compose file builds in its own way', () => {
    fs.writeFileSync(
      path.join(projectDir, 'docker-compose.dev.yml'),
      STOCK_DEV_COMPOSE.replace('target: dev', 'target: custom'),
    )

    const move = planBaseImageMove(projectDir, 'server', '6.1', stock)

    expect(move.writes).toEqual([])
    expect(move.skipped).toBe('docker-compose.dev.yml has a build section of your own')
  })

  it('does nothing for a project already on the base image', () => {
    fs.writeFileSync(path.join(projectDir, 'server', 'Dockerfile'), projectDockerfile('6.1'))

    expect(planBaseImageMove(projectDir, 'server', '6.1', stock)).toEqual({ writes: [] })
  })

  it('does nothing without a Dockerfile', () => {
    fs.rmSync(path.join(projectDir, 'server', 'Dockerfile'))

    expect(planBaseImageMove(projectDir, 'server', '6.1', stock)).toEqual({ writes: [] })
  })

  it('finds the Rails app at the root of a bare starter clone', () => {
    fs.rmSync(path.join(projectDir, 'server'), { recursive: true })
    fs.writeFileSync(path.join(projectDir, 'Dockerfile'), 'FROM ruby AS dev\n')
    fs.writeFileSync(path.join(projectDir, 'Gemfile'), "gem 'spree'\n")

    const move = planBaseImageMove(projectDir, 'server', '6.1', stock)

    expect(written(move)).toEqual(['docker-compose.dev.yml', 'Dockerfile'])
  })
})

describe('composeOnBaseImage, in a compose file with several services', () => {
  const compose = `services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
      target: dev
    ports:
      - "3000:3000"
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
`

  it('adds the development environment to the service that was built, not to another one', () => {
    expect(composeOnBaseImage(compose, '6.1')).toBe(`services:
  web:
    image: ghcr.io/spree/spree-base:6.1-build
    environment:
      RAILS_ENV: development
      BUNDLE_DEPLOYMENT: "0"
      BUNDLE_WITHOUT: ""
    ports:
      - "3000:3000"
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
`)
  })

  it('does not repeat a variable the service already sets', () => {
    const withEnv = compose.replace(
      '    ports:\n',
      '    environment:\n      RAILS_ENV: development\n    ports:\n',
    )
    const moved = composeOnBaseImage(withEnv, '6.1') as string
    expect(moved.match(/RAILS_ENV:/g)).toHaveLength(1)
    expect(moved).toContain('      BUNDLE_WITHOUT: ""\n      RAILS_ENV: development\n')
  })
})

describe('composeOnBaseImage, with less common compose shapes', () => {
  it('writes list items when the service lists its environment', () => {
    const compose =
      'services:\n  web:\n    build:\n      context: .\n      dockerfile: Dockerfile\n    environment:\n      - DATABASE_HOST=postgres\n'
    expect(composeOnBaseImage(compose, '6.1')).toBe(
      'services:\n  web:\n    image: ghcr.io/spree/spree-base:6.1-build\n    environment:\n      - RAILS_ENV=development\n      - BUNDLE_DEPLOYMENT=0\n      - BUNDLE_WITHOUT=\n      - DATABASE_HOST=postgres\n',
    )
  })

  it('is null when a key of the project follows the stock ones after a blank line', () => {
    const compose =
      'services:\n  web:\n    build:\n      context: .\n      dockerfile: Dockerfile\n\n      args:\n        FOO: bar\n'
    expect(composeOnBaseImage(compose, '6.1')).toBeNull()
  })
})

describe('composeOnBaseImage, across a whole service', () => {
  it('uses an environment block that sits above the build block', () => {
    const compose =
      'services:\n  web:\n    environment:\n      DATABASE_HOST: postgres\n    build:\n      context: .\n      dockerfile: Dockerfile\n      target: dev\n    ports:\n      - "3000:3000"\n'
    const moved = composeOnBaseImage(compose, '6.1') as string
    expect(moved.match(/environment:/g)).toHaveLength(1)
    expect(moved).toBe(
      'services:\n  web:\n    environment:\n      RAILS_ENV: development\n      BUNDLE_DEPLOYMENT: "0"\n      BUNDLE_WITHOUT: ""\n      DATABASE_HOST: postgres\n    image: ghcr.io/spree/spree-base:6.1-build\n    ports:\n      - "3000:3000"\n',
    )
  })

  it('moves every service that builds the stock Dockerfile', () => {
    const service = (name: string) =>
      `  ${name}:\n    build:\n      context: .\n      dockerfile: Dockerfile\n      target: dev\n`
    const moved = composeOnBaseImage(
      `services:\n${service('web')}${service('worker')}`,
      '6.1',
    ) as string
    expect(moved).not.toContain('build:')
    expect(moved.match(/image: ghcr\.io\/spree\/spree-base:6\.1-build/g)).toHaveLength(2)
    expect(moved.match(/RAILS_ENV: development/g)).toHaveLength(2)
  })
})

describe('onBaseImageLine', () => {
  it('moves line tags of an older Spree line, in Dockerfiles and compose files', () => {
    expect(onBaseImageLine(projectDockerfile('6.1'), '6.2')).toBe(
      projectDockerfile('6.2').replace(
        'spree-base:6.2-202611160323',
        'spree-base:6.1-202611160323',
      ),
    )
    expect(onBaseImageLine('    image: ghcr.io/spree/spree-base:6.1-build\n', '6.2')).toBe(
      '    image: ghcr.io/spree/spree-base:6.2-build\n',
    )
  })

  it('leaves a pinned build, the same line and a newer line alone', () => {
    expect(
      onBaseImageLine('ARG SPREE_BASE=ghcr.io/spree/spree-base:6.1-202611160323\n', '6.2'),
    ).toBeNull()
    expect(onBaseImageLine(projectDockerfile('6.2'), '6.2')).toBeNull()
    expect(onBaseImageLine('image: ghcr.io/spree/spree-base:6.3-build\n', '6.2')).toBeNull()
  })
})

describe('planBaseImageMove, for a project already on the base image', () => {
  let projectDir: string

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-base-image-line-'))
    fs.mkdirSync(path.join(projectDir, 'server'))
    fs.writeFileSync(path.join(projectDir, 'server', 'Gemfile'), "gem 'spree'\n")
    fs.writeFileSync(path.join(projectDir, 'server', 'Dockerfile'), projectDockerfile('6.1'))
    fs.writeFileSync(
      path.join(projectDir, 'docker-compose.yml'),
      'services:\n  web:\n    image: ghcr.io/spree/spree-base:6.1-build\n    volumes:\n      - ./server:/rails\n',
    )
  })

  afterEach(() => fs.rmSync(projectDir, { recursive: true, force: true }))

  // The build refuses a base image older than the project's Spree.
  it('moves the line up when the project moves to a newer Spree line', () => {
    const move = planBaseImageMove(projectDir, 'server', '6.2')

    expect(move.lineOnly).toBe(true)
    expect(move.writes.map(({ file }) => path.relative(projectDir, file))).toEqual([
      'server/Dockerfile',
      'docker-compose.yml',
    ])
    expect(move.writes[0].content).toContain('ARG SPREE_BASE=ghcr.io/spree/spree-base:6.2\n')
    expect(move.writes[1].content).toContain('image: ghcr.io/spree/spree-base:6.2-build\n')
  })

  it('does nothing on the same line', () => {
    expect(planBaseImageMove(projectDir, 'server', '6.1')).toEqual({ writes: [] })
  })
})
