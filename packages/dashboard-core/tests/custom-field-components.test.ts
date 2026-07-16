import { beforeEach, describe, expect, it } from 'vitest'
import {
  __resetCustomFieldComponents,
  type CustomFieldComponent,
  customFieldComponents,
} from '../src/lib/custom-field-components'

const FakeComponent: CustomFieldComponent = () => null
const OtherComponent: CustomFieldComponent = () => null

describe('customFieldComponents registry', () => {
  beforeEach(() => {
    __resetCustomFieldComponents()
  })

  it('registers and resolves by namespace.key', () => {
    customFieldComponents.register('specs.color', FakeComponent)
    expect(customFieldComponents.get('specs.color')).toBe(FakeComponent)
  })

  it('returns undefined for unregistered definitions (default widget renders)', () => {
    expect(customFieldComponents.get('specs.unknown')).toBeUndefined()
  })

  it('throws on duplicate registration', () => {
    customFieldComponents.register('specs.color', FakeComponent)
    expect(() => customFieldComponents.register('specs.color', OtherComponent)).toThrow(
      /already registered/,
    )
  })

  it('remove() unregisters and is a no-op when absent', () => {
    customFieldComponents.register('specs.color', FakeComponent)
    customFieldComponents.remove('specs.color')
    expect(customFieldComponents.get('specs.color')).toBeUndefined()
    expect(() => customFieldComponents.remove('specs.color')).not.toThrow()
  })
})
