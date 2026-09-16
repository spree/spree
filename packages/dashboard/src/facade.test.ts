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
function exportsOf(entry: string) {
  const file = require.resolve(entry, { paths: [__dirname] })
  const program = ts.createProgram([file], {
    moduleResolution: ts.ModuleResolutionKind.Bundler,
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
    jsx: ts.JsxEmit.ReactJSX,
    skipLibCheck: true,
    noEmit: true,
  })
  const checker = program.getTypeChecker()
  const source = program.getSourceFile(file)
  if (!source) throw new Error(`could not load ${entry}`)
  const symbol = checker.getSymbolAtLocation(source)
  if (!symbol) throw new Error(`no module symbol for ${entry}`)
  return { checker, exports: checker.getExportsOfModule(symbol) }
}

function resolve(checker: ts.TypeChecker, symbol?: ts.Symbol) {
  if (!symbol) return ''
  let current = symbol
  while (current.flags & ts.SymbolFlags.Alias) current = checker.getAliasedSymbol(current)
  return current.declarations?.[0]?.getSourceFile().fileName ?? ''
}

describe('@spree/dashboard facade', () => {
  const core = exportsOf('@spree/dashboard-core')
  const ui = exportsOf('@spree/dashboard-ui')
  const duplicates = core.exports
    .map((s) => s.getName())
    .filter((name) => ui.exports.some((s) => s.getName() === name))

  it('re-exports every duplicate explicitly, resolved to the framework', () => {
    const { checker, exports } = exportsOf(path.join(__dirname, 'index.ts'))

    for (const name of duplicates) {
      const symbol = exports.find((s) => s.getName() === name)
      expect(
        symbol,
        `${name} is declared by both packages and was dropped from the facade`,
      ).toBeDefined()

      // A name one package merely forwards from the other is the same symbol,
      // so either resolution is correct. Only genuinely distinct pairs — the
      // design system's presentational component and the framework's
      // data-fetching wrapper — need the framework's version to win.
      const viaCore = resolve(
        core.checker,
        core.exports.find((s) => s.getName() === name),
      )
      const viaUi = resolve(
        ui.checker,
        ui.exports.find((s) => s.getName() === name),
      )
      if (viaCore === viaUi) continue

      const from = resolve(checker, symbol)
      expect(from, `${name} resolves to the design system, not the framework`).toContain(
        'dashboard-core',
      )
    }
  })

  it('exposes the shell alongside the re-exports', () => {
    const { exports } = exportsOf(path.join(__dirname, 'index.ts'))
    const names = exports.map((s) => s.getName())
    expect(names).toContain('Dashboard')
    expect(names).toContain('createDashboardRouter')
    expect(names).toContain('defineDashboardPlugin')
  })
})
