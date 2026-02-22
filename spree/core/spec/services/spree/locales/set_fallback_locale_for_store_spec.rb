require 'spec_helper'

module Spree
  describe Locales::SetFallbackLocaleForStore do
    let(:command) { described_class.new }

    describe '#call' do
      let(:store) { create(:store, default_locale: 'pl', supported_locales: 'en,de,pl') }
      let(:product) { create(:product, name: 'test') }

      let(:name_en) { 'name en' }
      let(:name_pl) { 'name pl' }

      let!(:translation_en) { product.translations.find_or_create_by(locale: 'en') { |e| e.name = name_en } }
      let!(:translation_pl) { product.translations.find_or_create_by(locale: 'pl') { |e| e.name = name_pl } }

      before { command.call(store: store) }

      context 'when translatable object does not have a translation in the requested locale' do
        it 'sets mobility to retrieve value in the fallback locale' do
          name = I18n.with_locale(:de) { product.name }
          expect(name).to eq(name_pl)
        end
      end

      context 'when translatable object has a translation in the requested locale' do
        let(:name_de) { 'name de' }
        let!(:translation_de) { product.translations.find_or_create_by(locale: 'de') { |e| e.name = name_de } }

        it 'sets mobility to retrieve value directly' do
          name = I18n.with_locale(:de) { product.name }
          expect(name).to eq(name_de)
        end
      end
    end
  end
end
