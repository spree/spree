import path from 'node:path'
import ts from 'typescript'
import { describe, expect, it } from 'vitest'

// `@spree/dashboard` re-exports the framework and the design system so an
// application has one import to remember. TypeScript drops a name declared by
// both rather than picking one, which would silently remove it from the public
// API — so every duplicate must be re-exported explicitly in src/index.ts.
//
// This test fails when a new name appears in both packages. The fix is to add
// it to that explicit list, choosing the version an application should get
// (almost always the framework's: it fetches its own data).
//
// One program covers all three modules: src/index.ts re-exports the other two,
// so they are already in its dependency graph. Compiling them separately costs
// a full graph walk each, which is slow enough to time out on a cold CI runner.
const entry = path.join(__dirname, 'index.ts')
const core = require.resolve('@spree/dashboard-core', { paths: [__dirname] })
const ui = require.resolve('@spree/dashboard-ui', { paths: [__dirname] })

const program = ts.createProgram([entry], {
  moduleResolution: ts.ModuleResolutionKind.Bundler,
  module: ts.ModuleKind.ESNext,
  target: ts.ScriptTarget.ES2022,
  jsx: ts.JsxEmit.ReactJSX,
  skipLibCheck: true,
  noEmit: true,
})
const checker = program.getTypeChecker()

function exportsOf(file: string) {
  const source = program.getSourceFile(file)
  if (!source) throw new Error(`could not load ${file}`)
  const symbol = checker.getSymbolAtLocation(source)
  if (!symbol) throw new Error(`no module symbol for ${file}`)
  return checker.getExportsOfModule(symbol)
}

/** Follows alias chains to the declaration a name ultimately comes from. */
function origin(symbol?: ts.Symbol) {
  if (!symbol) return ''
  let current = symbol
  while (current.flags & ts.SymbolFlags.Alias) current = checker.getAliasedSymbol(current)
  return current.declarations?.[0]?.getSourceFile().fileName ?? ''
}

describe('@spree/dashboard facade', () => {
  const coreExports = exportsOf(core)
  const uiExports = exportsOf(ui)
  const facadeExports = exportsOf(entry)

  const duplicates = coreExports
    .map((symbol) => symbol.getName())
    .filter((name) => uiExports.some((symbol) => symbol.getName() === name))

  it('re-exports every duplicate explicitly, resolved to the framework', () => {
    for (const name of duplicates) {
      const symbol = facadeExports.find((s) => s.getName() === name)
      expect(
        symbol,
        `${name} is declared by both packages and was dropped from the facade`,
      ).toBeDefined()

      // A name one package merely forwards from the other is the same symbol,
      // so either resolution is correct. Only genuinely distinct pairs — the
      // design system's presentational component and the framework's
      // data-fetching wrapper — need the framework's version to win.
      const viaCore = origin(coreExports.find((s) => s.getName() === name))
      const viaUi = origin(uiExports.find((s) => s.getName() === name))
      if (viaCore === viaUi) continue

      expect(origin(symbol), `${name} resolves to the design system, not the framework`).toContain(
        'dashboard-core',
      )
    }
  })

  it('exposes the shell alongside the re-exports', () => {
    const names = facadeExports.map((symbol) => symbol.getName())

    expect(names).toContain('Dashboard')
    expect(names).toContain('createDashboardRouter')
    expect(names).toContain('defineDashboardPlugin')
  })
})
