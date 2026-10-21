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

  # OptionType's translatable column and public name are both `label` since
  # 6.0, so this covers the identity case the alias mechanism falls back to.
  describe 'public translatable fields' do
    let!(:option_type) { create(:option_type, name: 'size', label: 'Size') }

    it 'exposes the public field name' do
      expect(Spree::OptionType.public_translatable_fields).to eq([:label])
    end

    it 'upserts via the public name and writes the internal Mobility field' do
      option_type.upsert_translations('de' => { 'label' => 'Größe' })

      Mobility.with_locale(:de) { expect(option_type.reload.label).to eq 'Größe' }
      Mobility.with_locale(:en) { expect(option_type.reload.label).to eq 'Size' }
    end

    it 'reports untranslated fields as nil in the matrix' do
      matrix = Spree::Translations.matrix_for(option_type, locales: %w[de])
      expect(matrix.dig('de', 'label')).to be_nil
    end
  end

  describe '.with_translation_fallback_order' do
    let!(:alpha) { create(:product, name: 'Alpha', store: store) }
    let!(:bravo) { create(:product, name: 'Bravo', store: store) }
    let!(:charlie) { create(:product, name: 'Charlie', store: store) }

    before do
      create(:product_translation, translated_model: charlie, locale: 'de', name: 'Anton')
      create(:product_translation, translated_model: bravo, locale: 'de', name: '')
    end

    def sorted(direction, distinct: true)
      Spree::Product.where(id: [alpha, bravo, charlie]).
        ransack(s: "name #{direction}").result(distinct: distinct).
        with_translation_fallback_order
    end

    it 'sorts by the translation, falling back to the base name when it is missing or blank' do
      Mobility.with_locale(:de) do
        expect(sorted(:asc).to_a).to eq([alpha, charlie, bravo])
        expect(sorted(:desc).to_a).to eq([bravo, charlie, alpha])
      end
    end

    it 'sorts and counts a relation without DISTINCT' do
      Mobility.with_locale(:de) do
        expect(sorted(:asc, distinct: false).to_a).to eq([alpha, charlie, bravo])
        expect(sorted(:asc, distinct: false).count(:all)).to eq(3)
      end
    end

    it 'leaves a sort in the content locale on the base column' do
      Mobility.with_locale(:en) { expect(sorted(:asc).to_a).to eq([alpha, bravo, charlie]) }
    end
  end

  describe '.translatable_rich_text_fields' do
    it 'returns the fields a model declares as rich text' do
      expect(Spree::Product.translatable_rich_text_fields).to eq(%i[description])
      expect(Spree::Policy.translatable_rich_text_fields).to eq(%i[body])
    end

    it 'defaults to none when a model declares no rich-text fields' do
      expect(Spree::OptionType.translatable_rich_text_fields).to eq([])
    end
  end
end
