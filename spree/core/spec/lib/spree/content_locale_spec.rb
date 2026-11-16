require 'spec_helper'

# The request's content locale (Spree::Current.content_locale) carries "which
# locale is authored in base columns" through request-local state. These specs
# pin the contract that replaced the old per-request mutation of the
# process-global I18n.default_locale, which is shared by every thread in the
# server process and leaked one request's locale into others.
RSpec.describe 'content locale request state' do
  describe 'Spree.use_translations?' do
    it 'is false when the current locale matches the content locale' do
      Spree::Current.content_locale = 'de'

      I18n.with_locale(:de) { expect(Spree.use_translations?).to be(false) }
    end

    it 'is true when the current locale differs from the content locale' do
      Spree::Current.content_locale = 'de'

      I18n.with_locale(:en) { expect(Spree.use_translations?).to be(true) }
    end

    it 'defaults the content locale to the application default outside a request' do
      I18n.with_locale(I18n.default_locale) { expect(Spree.use_translations?).to be(false) }
    end

    it 'is always true when always_use_translations is enabled' do
      allow(Spree::Config).to receive(:always_use_translations).and_return(true)
      Spree::Current.content_locale = I18n.locale.to_s

      expect(Spree.use_translations?).to be(true)
    end
  end

  describe 'Spree.mobility_column_fallback' do
    it 'targets the base column only for the request content locale' do
      column_fallback = Spree.mobility_column_fallback
      Spree::Current.content_locale = 'de'

      expect(column_fallback.call(:de)).to be(true)
      expect(column_fallback.call(:en)).to be(false)
    end

    it 'disables the base-column fallback entirely when always_use_translations is enabled' do
      allow(Spree::Config).to receive(:always_use_translations).and_return(true)

      expect(Spree.mobility_column_fallback).to be(false)
    end
  end

  describe 'translated attribute reads' do
    it 'read the base column for the content locale and the translation table otherwise' do
      product = create(:product, name: 'Base name')
      product.translations.create!(locale: 'de', name: 'German translation')

      # Default content locale (application default): :de reads the translation.
      expect(Mobility.with_locale(:de) { Spree::Product.find(product.id).name }).to eq('German translation')

      # Content locale :de (a request for a German store): :de reads the base column.
      Spree::Current.content_locale = 'de'
      expect(Mobility.with_locale(:de) { Spree::Product.find(product.id).name }).to eq('Base name')
    end
  end

  describe 'locale state reset between requests' do
    it "installs the i18n gem's config-resetting middleware" do
      # I18n.locale lives in fiber-local storage that survives across requests
      # on reused server threads; the gem's middleware resets it per request.
      expect(Rails.application.middleware.map(&:name)).to include('I18n::Middleware')
    end

    it 'request-scopes store-based Mobility fallbacks so RequestStore clears them per request' do
      custom_fallbacks = I18n::Locale::Fallbacks.new(:de)
      Mobility.store_based_fallbacks = custom_fallbacks

      RequestStore.clear!

      expect(Mobility.store_based_fallbacks).not_to be(custom_fallbacks)
    end
  end
end
