require 'spec_helper'

# Exercised through Spree::Product, which includes Spree::TranslatableResource.
RSpec.describe Spree::TranslatableResource, type: :model do
  let(:store) { @default_store }
  let!(:product) { create(:product, name: 'Espresso Machine', store: store) }

  before do
    store.update_column(:supported_locales, 'en,de,fr')
    allow(Spree::Current).to receive(:store).and_return(store)
  end

  describe '#upsert_translations' do
    it 'writes a translation under the given locale, leaving the source untouched' do
      product.upsert_translations('de' => { 'name' => 'Espressomaschine' })

      Mobility.with_locale(:de) { expect(product.reload.name).to eq 'Espressomaschine' }
      Mobility.with_locale(:en) { expect(product.reload.name).to eq 'Espresso Machine' }
    end

    it 'upserts multiple locales and fields in one call' do
      product.upsert_translations(
        'de' => { 'name' => 'Espressomaschine', 'meta_title' => 'DE Title' },
        'fr' => { 'name' => 'Machine à espresso' }
      )

      Mobility.with_locale(:de) do
        expect(product.reload.name).to eq 'Espressomaschine'
        expect(product.meta_title).to eq 'DE Title'
      end
      Mobility.with_locale(:fr) { expect(product.reload.name).to eq 'Machine à espresso' }
    end

    it 'only touches fields present in the payload (omit-to-leave-alone)' do
      product.upsert_translations('de' => { 'name' => 'Alt', 'meta_title' => 'Alt Title' })
      product.upsert_translations('de' => { 'name' => 'Neu' })

      Mobility.with_locale(:de) do
        expect(product.reload.name).to eq 'Neu'
        expect(product.meta_title).to eq 'Alt Title'
      end
    end

    it 'ignores fields outside TRANSLATABLE_FIELDS' do
      product.upsert_translations('de' => { 'name' => 'Espressomaschine', 'status' => 'archived' })
      expect(product.reload.status).not_to eq 'archived'
    end

    it 'raises RecordInvalid for an unsupported locale, without writing' do
      expect {
        product.upsert_translations('es' => { 'name' => 'Máquina de espresso' })
      }.to raise_error(ActiveRecord::RecordInvalid, /es/)

      Mobility.with_locale(:es) { expect(product.reload.name).not_to eq 'Máquina de espresso' }
    end
  end

  # OptionType exposes the translatable column `presentation` under the public
  # name `label` — the matrix and upsert use the public name.
  describe 'public field aliases (OptionType#label → presentation)' do
    let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }

    it 'exposes the public field name' do
      expect(Spree::OptionType.public_translatable_fields).to eq([:label])
    end

    it 'upserts via the public name and writes the internal Mobility field' do
      option_type.upsert_translations('de' => { 'label' => 'Größe' })

      Mobility.with_locale(:de) { expect(option_type.reload.presentation).to eq 'Größe' }
      Mobility.with_locale(:en) { expect(option_type.reload.presentation).to eq 'Size' }
    end

    it 'reports untranslated fields as nil in the matrix (fallback honored through the alias)' do
      matrix = Spree::Translations.matrix_for(option_type, locales: %w[de])
      expect(matrix.dig('de', 'label')).to be_nil
    end
  end
end
