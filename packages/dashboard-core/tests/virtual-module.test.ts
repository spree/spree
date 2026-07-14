import { describe, expect, it } from 'vitest'
import { generateVirtualPluginModule, VIRTUAL_PLUGIN_MODULE_ID } from '../src/vite'

describe('generateVirtualPluginModule', () => {
  it('emits one side-effect import per plugin, in order', () => {
    const code = generateVirtualPluginModule(['@acme/reviews-plugin', 'wishlists-plugin'])
    expect(code).toContain('import "@acme/reviews-plugin"')
    expect(code).toContain('import "wishlists-plugin"')
    expect(code.indexOf('@acme/reviews-plugin')).toBeLessThan(code.indexOf('wishlists-plugin'))
    expect(code).toContain('export {}')
  })

  it('emits an empty module when no plugins are installed', () => {
    const code = generateVirtualPluginModule([])
    expect(code).not.toContain('import "')
    expect(code).toContain('export {}')
  })

  it('escapes package names as string literals', () => {
    const code = generateVirtualPluginModule(['@acme/it\'s-a-plugin"'])
    expect(code).toContain(JSON.stringify('@acme/it\'s-a-plugin"'))
  })

  it('exposes the module id hosts import', () => {
    expect(VIRTUAL_PLUGIN_MODULE_ID).toBe('virtual:spree-dashboard-plugins')
  })
})
