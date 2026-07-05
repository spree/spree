require 'spec_helper'

describe 'spree/admin/shared/_head.html.erb', type: :view do
  let(:store) { build_stubbed(:store) }

  before do
    allow(view).to receive(:current_store).and_return(store)
    allow(view).to receive(:controller_name).and_return('dashboard')
  end

  # Regression: store name fields are Mobility-translated. When the admin UI
  # locale differs from the store's default locale and no translation exists,
  # `current_store.name` is nil — the title must not call `nil.capitalize`.
  context 'when the store name is blank in the current locale' do
    let(:store) { build_stubbed(:store, name: nil) }

    it 'renders without raising' do
      expect { render }.not_to raise_error
    end
  end

  context 'when the store has a name' do
    let(:store) { build_stubbed(:store, name: 'acme') }

    it 'appends the capitalized store name to the title' do
      render
      expect(rendered).to include('Acme')
    end
  end

  context 'when the locale is RTL' do
    before do
      allow(view).to receive(:rtl_locale?).and_return(true)
    end

    it 'loads the Arabic web font' do
      render
      expect(rendered).to include('Noto+Sans+Arabic')
    end
  end
end
