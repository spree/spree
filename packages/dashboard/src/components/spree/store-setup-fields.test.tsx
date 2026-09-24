import { renderToStaticMarkup } from 'react-dom/server'
import { useForm } from 'react-hook-form'
import { describe, expect, it } from 'vitest'
import { StoreSetupFields } from './store-setup-fields'

function SetupForm() {
  const form = useForm({
    defaultValues: { store_name: '', country_code: '', locale: 'en', currency: 'USD' },
  })
  return <StoreSetupFields form={form} countries={[]} />
}

// Deliberately no `i18n-setup` import: a host app mounting these fields on
// their own screens only has the framework's translations loaded.
describe('StoreSetupFields', () => {
  it('renders translated labels with only the framework translations loaded', () => {
    const html = renderToStaticMarkup(<SetupForm />)

    expect(html).toContain('Store name')
    expect(html).toContain('Country')
    expect(html).not.toContain('admin.fields.setup')
  })
})
