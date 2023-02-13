require 'spec_helper'

module Spree
  describe Products::Translations::GenerateAutomatedTranslations do
    describe '#call' do
      subject do
        generate_automated_translations.call(product: product,
                                             source_locale: source_locale,
                                             target_locales: target_locales,
                                             skip_existing: skip_existing)
      end

      let(:generate_automated_translations) { described_class.new(provider: provider) }

      let(:provider) { double }
      let(:source_locale) { 'en' }
      let(:target_locales) { %w[de fr] }
      let(:skip_existing) { false }

      let(:de_attributes) { { name: 'DE Name', description: 'DE Description' } }
      let(:fr_attributes) { { name: 'FR Name', description: 'FR Description' } }

      context 'when there are existing translations in the target language' do
        let(:product) { create(:product, translations: [product_translation_fr]) }
        let(:product_translation_fr) do
          build(:product_translation,
                locale: 'fr',
                name: 'FR Name Original',
                description: 'FR Description Original')
        end

        context 'when skip existing is set to true' do
          let(:skip_existing) { true }

          it 'fetches only the missing locales from the provider' do
            expect(provider).to receive(:call).with(hash_including(source_locale: 'en', target_locale: 'de')).and_return(Spree::ServiceModule::Result.new(true, de_attributes, nil))
            expect(provider).to_not receive(:call).with(hash_including(source_locale: 'en', target_locale: 'fr'))

            subject

            de_translation = product.translations.find_by(locale: 'de')
            fr_translation = product.translations.find_by(locale: 'fr')
            expect(de_translation.name).to eq('DE Name')
            expect(de_translation.description).to eq('DE Description')
            expect(fr_translation.name).to eq('FR Name Original')
            expect(fr_translation.description).to eq('FR Description Original')
          end
        end

        context 'when skip existing is set to false' do
          let(:skip_existing) { false }

          it 'fetches all target locales from the provider' do
            expect(provider).to receive(:call).with(hash_including(source_locale: 'en', target_locale: 'de')).and_return(Spree::ServiceModule::Result.new(true, de_attributes, nil))
            expect(provider).to receive(:call).with(hash_including(source_locale: 'en', target_locale: 'fr')).and_return(Spree::ServiceModule::Result.new(true, fr_attributes, nil))

            subject

            de_translation = product.translations.find_by(locale: 'de')
            fr_translation = product.translations.find_by(locale: 'fr')
            expect(de_translation.name).to eq('DE Name')
            expect(de_translation.description).to eq('DE Description')
            expect(fr_translation.name).to eq('FR Name')
            expect(fr_translation.description).to eq('FR Description')
          end
        end

        context 'when no target locales are defined' do
          let(:target_locales) { [] }

          it 'raises an error' do
            expect { subject }.to raise_error(ArgumentError, 'No locales available to translate to')
          end
        end
      end

      context 'when no provider is set' do
        let(:provider) { nil }
        let(:product) { create(:product) }

        it 'raises an error' do
          expect { subject }.to raise_error(ArgumentError, 'Automated translations service not available')
        end
      end
    end
  end
end
