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
end
