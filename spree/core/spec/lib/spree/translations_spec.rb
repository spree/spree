require 'spec_helper'

RSpec.describe Spree::Translations do
  let(:store) { @default_store }
  let!(:product) { create(:product, name: 'Espresso Machine', store: store) }

  before do
    store.update!(supported_locales: 'en,de,fr')
    allow(Spree::Current).to receive(:store).and_return(store)
    Mobility.with_locale(:de) { product.update!(name: 'Espressomaschine', meta_title: 'DE Title') }
  end

  describe '.matrix_for' do
    subject { described_class.matrix_for(product) }

    it 'returns a matrix keyed by non-default locale' do
      expect(subject.keys).to match_array(%w[de fr])
    end

    it 'fills translated values and a per-locale completeness count' do
      expect(subject['de']['name']).to eq 'Espressomaschine'
      expect(subject['de']['meta_title']).to eq 'DE Title'
      # name + meta_title + the auto-generated localized slug
      expect(subject['de']['translated_field_count']).to eq 3
      expect(subject['fr']['name']).to be_nil
      expect(subject['fr']['translated_field_count']).to eq 0
    end
  end

  describe '.fields_for' do
    subject { described_class.fields_for(product) }

    it 'returns key + type + source for each translatable field' do
      name_field = subject.find { |f| f['key'] == 'name' }
      expect(name_field['source']).to eq 'Espresso Machine'
      expect(name_field['type']).to eq 'string'

      # description is declared rich text; slug is a plain string field
      expect(subject.find { |f| f['key'] == 'description' }['type']).to eq 'html'
      expect(subject.find { |f| f['key'] == 'slug' }['type']).to eq 'string'
    end
  end

  describe '.registry' do
    subject { described_class.registry }

    it 'exposes every translatable resource and its fields' do
      product_entry = subject.find { |r| r['resource_type'] == 'product' }
      expect(product_entry['fields'].map { |f| f['key'] }).to include('name', 'description', 'slug')
    end
  end

  describe '.translated_counts' do
    let!(:other_product) { create(:product, name: 'Drip Coffee Maker', store: store) }

    subject { described_class.translated_counts(Spree::Product.where(store: store), Spree::Product, %w[de fr]) }

    it 'counts the filled fields per record per locale' do
      # name + meta_title + the slug derived from the translated name
      expect(subject[product.id]['de']).to eq 3
    end

    it 'omits a record with no translation rather than reporting zeros' do
      expect(subject[other_product.id]).to be_nil
    end

    it 'omits a locale the record has no translation in' do
      expect(subject[product.id]['fr']).to be_nil
    end

    it 'returns nothing when no locales are asked for' do
      expect(described_class.translated_counts(Spree::Product.all, Spree::Product, [])).to eq({})
    end

    it 'uses the internal column for a publicly aliased field' do
      option_type = create(:option_type, label: 'Color')
      Mobility.with_locale(:de) { option_type.update!(label: 'Farbe') }

      counts = described_class.translated_counts(
        Spree::OptionType.where(id: option_type.id), Spree::OptionType, %w[de]
      )

      # `label` is both the public name and the column
      expect(counts[option_type.id]['de']).to eq 1
    end
  end

  describe '.translatable_scope' do
    let(:other_store) { create(:store) }

    it 'narrows a store-column model to the store' do
      mine = create(:product, store: store)
      theirs = create(:product, store: other_store)

      scope = Spree::Product.translatable_scope(store)
      expect(scope).to include(mine)
      expect(scope).not_to include(theirs)
    end

    it 'narrows a polymorphic-owner model through its owner' do
      # spree_policies has no store_id — it hangs off `owner` — so anything
      # keying on the column would hand back every store's policies.
      mine = create(:policy, owner: store)
      theirs = create(:policy, owner: other_store)

      scope = Spree::Policy.translatable_scope(store)
      expect(scope).to include(mine)
      expect(scope).not_to include(theirs)
    end

    it 'narrows Store to the store itself, not every store in the install' do
      other_store

      expect(Spree::Store.translatable_scope(store)).to contain_exactly(store)
    end

    it 'returns everything for global reference data' do
      option_type = create(:option_type)

      expect(Spree::OptionType.translatable_scope(store)).to include(option_type)
    end
  end

  describe '.coverage_for' do
    let!(:other_product) { create(:product, name: 'Drip Coffee Maker', store: store) }

    subject { described_class.coverage_for(Spree::Product.where(store: store), Spree::Product, %w[de fr]) }

    it 'counts a record only when every translatable field is filled' do
      # The German translation covers 3 of 5 fields, so it is not complete.
      expect(subject.find { |row| row['locale'] == 'de' }).to include(
        'translated' => 0, 'total' => 2, 'coverage' => 0.0
      )
    end

    it 'counts a fully translated record' do
      Mobility.with_locale(:de) do
        product.update!(description: 'Zieht einen guten Shot.', meta_description: 'Kaufen.')
      end

      row = subject.find { |r| r['locale'] == 'de' }
      expect(row['translated']).to eq 1
      expect(row['coverage']).to eq 0.5
    end

    it 'does not count a whitespace-only translation as complete' do
      # The two counters must agree: a Ruby `present?` check treats " " as
      # blank, so the SQL side trims too — otherwise the coverage card and the
      # grid cells below it contradict each other.
      Mobility.with_locale(:de) do
        product.update!(description: '   ', meta_description: '   ')
      end

      expect(subject.find { |row| row['locale'] == 'de' }['translated']).to eq 0
    end

    it 'reports zero coverage without dividing by zero on an empty scope' do
      rows = described_class.coverage_for(Spree::Product.none, Spree::Product, %w[de])

      expect(rows.first).to include('translated' => 0, 'total' => 0, 'coverage' => 0.0)
    end
  end

end
