import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { render, substitute } from '../src/lib/template'

describe('substitute', () => {
  it('replaces known keys', () => {
    expect(substitute('Hello {{name}}!', { name: 'World' })).toBe('Hello World!')
  })

  it('leaves unknown keys untouched so typos surface', () => {
    expect(substitute('Hi {{nayme}} from {{place}}', { name: 'A', place: 'B' })).toBe(
      'Hi {{nayme}} from B',
    )
  })

  it('handles multiple keys + repeats', () => {
    expect(substitute('{{a}} - {{a}} - {{b}}', { a: 'x', b: 'y' })).toBe('x - x - y')
  })

  it('does not match incomplete tokens', () => {
    expect(substitute('{name}} {{name}', { name: 'x' })).toBe('{name}} {{name}')
  })
})

describe('render', () => {
  const tempDirs: string[] = []

  function tempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-template-test-'))
    tempDirs.push(dir)
    return dir
  }

  function writeFile(p: string, content: string): void {
    fs.mkdirSync(path.dirname(p), { recursive: true })
    fs.writeFileSync(p, content)
  }

  function read(p: string): string {
    return fs.readFileSync(p, 'utf8')
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  it('copies plain files verbatim', () => {
    const src = tempDir()
    const dst = path.join(tempDir(), 'out')
    writeFile(path.join(src, 'README.md'), 'unchanged content {{not_a_var}}')

    render({ src, dst, vars: {} })

    expect(read(path.join(dst, 'README.md'))).toBe('unchanged content {{not_a_var}}')
  })

  it('renders .tt files with substitution and strips the suffix', () => {
    const src = tempDir()
    const dst = path.join(tempDir(), 'out')
    writeFile(path.join(src, 'package.json.tt'), '{"name": "{{name}}"}')

    render({ src, dst, vars: { name: 'spree-brands' } })

    expect(fs.existsSync(path.join(dst, 'package.json.tt'))).toBe(false)
    expect(read(path.join(dst, 'package.json'))).toBe('{"name": "spree-brands"}')
  })

  it('substitutes variables in directory names', () => {
    const src = tempDir()
    const dst = path.join(tempDir(), 'out')
    writeFile(path.join(src, 'lib', '{{ruby_name}}', 'engine.rb'), 'module {{module_name}}; end')

    render({
      src,
      dst,
      vars: { ruby_name: 'spree_brands', module_name: 'SpreeBrands' },
    })

    expect(fs.existsSync(path.join(dst, 'lib', 'spree_brands', 'engine.rb'))).toBe(true)
    expect(read(path.join(dst, 'lib', 'spree_brands', 'engine.rb'))).toBe(
      'module {{module_name}}; end',
    )
  })

  it('substitutes variables in .tt content AND in path segments simultaneously', () => {
    const src = tempDir()
    const dst = path.join(tempDir(), 'out')
    writeFile(path.join(src, 'lib', '{{ruby_name}}.rb.tt'), 'require "{{ruby_name}}/engine"')

    render({ src, dst, vars: { ruby_name: 'spree_brands' } })

    expect(read(path.join(dst, 'lib', 'spree_brands.rb'))).toBe('require "spree_brands/engine"')
  })

  it('skips paths matching the skip predicate', () => {
    const src = tempDir()
    const dst = path.join(tempDir(), 'out')
    writeFile(path.join(src, 'packages', 'dashboard', 'index.ts'), '// dashboard')
    writeFile(path.join(src, 'engine', 'lib.rb'), '# engine')
    writeFile(path.join(src, 'README.md'), 'top-level')

    render({
      src,
      dst,
      vars: {},
      skip: (rel) => rel === 'engine' || rel.startsWith('engine/'),
    })

    expect(fs.existsSync(path.join(dst, 'engine'))).toBe(false)
    expect(fs.existsSync(path.join(dst, 'packages', 'dashboard', 'index.ts'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'README.md'))).toBe(true)
  })

  it('rejects a non-empty destination without force', () => {
    const src = tempDir()
    const dst = tempDir() // already exists, will populate below
    writeFile(path.join(src, 'file.txt'), 'a')
    writeFile(path.join(dst, 'preexisting.txt'), 'b')

    expect(() => render({ src, dst, vars: {} })).toThrow(/not empty/)
  })

  it('overwrites an existing destination with force=true', () => {
    const src = tempDir()
    const dst = tempDir()
    writeFile(path.join(src, 'file.txt'), 'new')
    writeFile(path.join(dst, 'old.txt'), 'remains')

    render({ src, dst, vars: {}, force: true })

    expect(read(path.join(dst, 'file.txt'))).toBe('new')
    // Force doesn't clean — old files remain unless they collide.
    expect(read(path.join(dst, 'old.txt'))).toBe('remains')
  })

  it('creates a missing destination directory', () => {
    const src = tempDir()
    const dst = path.join(tempDir(), 'does', 'not', 'exist', 'yet')
    writeFile(path.join(src, 'file.txt'), 'hello')

    render({ src, dst, vars: {} })

    expect(read(path.join(dst, 'file.txt'))).toBe('hello')
  })
})
