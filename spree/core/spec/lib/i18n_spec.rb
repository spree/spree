require 'spec_helper'

describe 'i18n' do
  before do
    I18n.backend.store_translations(:en, spree: { foo: 'bar', bar: { foo: 'bar within bar scope' } })
  end

  describe '#available_locales' do
    it 'returns the locales Spree ships translations for, including English' do
      expect(Spree.available_locales).to include(:en)
    end
  end

  describe '.t' do
    it 'translates within the spree scope' do
      expect(Spree.t(:foo)).to eq('bar')
    end

    it 'prepends the spree scope to a given scope' do
      expect(Spree.t(:foo, scope: 'bar')).to eq('bar within bar scope')
      expect(Spree.t(:foo, scope: [:bar])).to eq('bar within bar scope')
    end

    it 'warns that it is deprecated' do
      expect(Spree::Deprecation).to receive(:warn).with(/Spree\.t is deprecated/)

      Spree.t(:foo)
    end

    it 'never returns HTML for a missing key' do
      expect(Spree.t(:missing_entry, default: 'Missing entry')).to eq('Missing entry')
    end
  end
end
